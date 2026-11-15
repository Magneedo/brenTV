import AVFoundation
import AVKit
import Flutter
import MediaPlayer
import UIKit

final class IosPlayerBridge: NSObject, FlutterStreamHandler,
  AVPlayerViewControllerDelegate {
  private let player = AVPlayer()
  weak var parentController: UIViewController?
  private var controller: AVPlayerViewController?
  private var pipActive = false
  private var videoExpected: Bool?
  private var sink: FlutterEventSink?
  private var observations: [NSKeyValueObservation] = []
  private var itemObservations: [NSKeyValueObservation] = []
  private var notifications: [NSObjectProtocol] = []
  private var timer: Any?
  private var firstFrame = false
  private var quietFailure = false
  private var backgroundAudio = true
  private var autoPip = true
  private var resumeAfterInterruption = false
  private var wantsPlayback = false
  private var info: [String: Any] = [:]
  private var openTimeout: DispatchWorkItem?
  private var remoteTargets: [(MPRemoteCommand, Any)] = []

  init(messenger: FlutterBinaryMessenger, parent: UIViewController?) {
    super.init()
    parentController = parent
    try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
    let methods = FlutterMethodChannel(name: "brentv/ios_player", binaryMessenger: messenger)
    methods.setMethodCallHandler { [weak self] call, result in self?.handle(call, result) }
    FlutterEventChannel(name: "brentv/ios_player/events", binaryMessenger: messenger)
      .setStreamHandler(self)
    observations.append(player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
      DispatchQueue.main.async { self?.reportState() }
    })
    timer = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
                                         queue: .main) { [weak self] _ in self?.tick() }
    observe(AVAudioSession.interruptionNotification) { [weak self] note in self?.interrupted(note) }
    observe(AVAudioSession.routeChangeNotification) { [weak self] note in
      if (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt) == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
        self?.wantsPlayback = false
        self?.resumeAfterInterruption = false
        self?.player.pause()
      }
    }
    observe(UIApplication.didEnterBackgroundNotification) { [weak self] _ in self?.background() }
    observe(UIApplication.willEnterForegroundNotification) { [weak self] _ in
      guard let self = self else { return }
      self.controller?.player = self.player
      if !self.firstFrame, let item = self.player.currentItem, item.status != .failed {
        let timeout = DispatchWorkItem { [weak self, weak item] in
          guard let self = self, let item = item, item === self.player.currentItem, !self.firstFrame else { return }
          self.fail()
        }
        self.openTimeout?.cancel()
        self.openTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: timeout)
      }
    }
    observe(.AVPlayerItemDidPlayToEndTime) { [weak self] note in
      guard let self = self, let item = note.object as? AVPlayerItem, item === self.player.currentItem else { return }
      self.emit(["type": "state", "state": "ended"])
      self.tick()
    }
    observe(.AVPlayerItemFailedToPlayToEndTime) { [weak self] note in
      guard let self = self, let item = note.object as? AVPlayerItem, item === self.player.currentItem else { return }
      self.fail()
    }
    installRemoteCommands()
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    return nil
  }
  func onCancel(withArguments arguments: Any?) -> FlutterError? { sink = nil; return nil }
  private func emit(_ event: [String: Any]) { sink?(event) }
  private func observe(_ name: Notification.Name, action: @escaping (Notification) -> Void) {
    notifications.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main, using: action))
  }

  private func attach(_ controller: AVPlayerViewController) {
    self.controller = controller
    controller.player = player
    controller.delegate = self
    if #available(iOS 14.2, *) {
      controller.canStartPictureInPictureAutomaticallyFromInline = autoPip
    }
    layerObservation = controller.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] controller, _ in
      DispatchQueue.main.async {
        guard let self = self, controller === self.controller,
              controller.isReadyForDisplay, self.player.currentItem != nil else { return }
        self.firstFrame = true
        self.openTimeout?.cancel()
        self.emit(["type": "firstFrame"])
      }
    }
  }
  private var layerObservation: NSKeyValueObservation?

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "open":
      guard controller == nil else {
        result(FlutterError(code: "busy", message: "A video is already open", details: nil)); return
      }
      guard let parent = parentController, parent.viewIfLoaded?.window != nil,
            parent.presentedViewController == nil else {
        result(FlutterError(code: "presentation", message: "Could not present the video player", details: nil)); return
      }
      guard let raw = args["url"] as? String, let url = URL(string: raw),
            ["http", "https", "file"].contains(url.scheme?.lowercased() ?? "") else {
        result(FlutterError(code: "url", message: "Invalid stream address", details: nil)); return
      }
      stop()
      firstFrame = false
      quietFailure = args["quietFailure"] as? Bool ?? false
      videoExpected = nil
      backgroundAudio = args["backgroundAudio"] as? Bool ?? true
      autoPip = args["autoPip"] as? Bool ?? true
      if #available(iOS 14.2, *) {
        controller?.canStartPictureInPictureAutomaticallyFromInline = autoPip
      }
      let headers = (args["headers"] as? [String: String] ?? [:]).filter { ["User-Agent", "Referer", "Origin"].contains($0.key) }
      guard headers["Referer"]?.isEmpty != false && headers["Origin"]?.isEmpty != false else {
        result(FlutterError(code: "headers", message: "Apple’s player does not support the custom headers required by this source", details: nil)); return
      }
      var assetOptions: [String: Any] = [:]
      if let agent = headers["User-Agent"], !agent.isEmpty {
        if #available(iOS 16.0, *) { assetOptions[AVURLAssetHTTPUserAgentKey] = agent }
        else { result(FlutterError(code: "headers", message: "Apple’s player requires iOS 16 or later for this source’s custom user agent", details: nil)); return }
      }
      let asset = AVURLAsset(url: url, options: assetOptions)
      let item = AVPlayerItem(asset: asset)
      if #available(iOS 15.0, *) {
        player.audiovisualBackgroundPlaybackPolicy = backgroundAudio ? .continuesIfPossible : .pauses
      }
      item.preferredPeakBitRate = (args["maxBitrate"] as? NSNumber)?.doubleValue ?? 0
      item.preferredMaximumResolution = CGSize(width: (args["width"] as? NSNumber)?.doubleValue ?? 0,
                                               height: (args["height"] as? NSNumber)?.doubleValue ?? 0)
      let seconds = max(0, (args["startSeconds"] as? NSNumber)?.doubleValue ?? 0)
      var seekWhenReady = seconds > 0 || args["fromStart"] as? Bool == true
      itemObservations = [item.observe(\.tracks, options: [.initial, .new]) { [weak self] item, _ in
        DispatchQueue.main.async {
          guard let self = self, item === self.player.currentItem else { return }
          let types = item.tracks.compactMap { $0.assetTrack?.mediaType }
          self.videoExpected = types.contains(.video) ? true : (types.contains(.audio) ? false : nil)
        }
      }, item.observe(\.status, options: [.new]) { [weak self] item, _ in
        DispatchQueue.main.async {
          guard let self = self, item === self.player.currentItem else { return }
          if item.status == .failed { self.fail() }
          // A seek before readiness is ignored for a growing EVENT playlist.
          if item.status == .readyToPlay && seekWhenReady {
            seekWhenReady = false
            self.player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
          }
        }
      }, item.observe(\.presentationSize, options: [.new]) { [weak self] item, _ in
        DispatchQueue.main.async {
          guard let self = self, item === self.player.currentItem else { return }
          self.emit(["type": "videoSize", "width": item.presentationSize.width, "height": item.presentationSize.height])
        }
      }]
      emit(["type": "state", "state": "loading"])
      player.replaceCurrentItem(with: item)
      let nativeController = AVPlayerViewController()
      nativeController.modalPresentationStyle = .fullScreen
      nativeController.showsPlaybackControls = true
      nativeController.updatesNowPlayingInfoCenter = false
      nativeController.allowsPictureInPicturePlayback = autoPip
      attach(nativeController)
      setNowPlaying(args)
      let timeout = DispatchWorkItem { [weak self, weak item] in
        guard let self = self, let item = item, item === self.player.currentItem else { return }
        if !self.firstFrame { self.fail() }
      }
      openTimeout = timeout
      DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: timeout)
      wantsPlayback = true
      parent.present(nativeController, animated: true) { [weak self] in
        guard let self = self, self.controller === nativeController, item.status != .failed else { result(nil); return }
        do { try self.activate(); self.player.play() } catch { self.fail() }
        result(nil)
      }
      return
    case "setTitle":
      if player.currentItem != nil, let title = args["title"] as? String {
        info[MPMediaItemPropertyTitle] = title
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
      }
    case "play":
      wantsPlayback = true
      do { try activate(); player.play() } catch { fail() }
    case "pause": wantsPlayback = false; resumeAfterInterruption = false; player.pause()
    case "seek":
      let seconds = (args["seconds"] as? NSNumber)?.doubleValue ?? 0
      player.seek(to: CMTime(seconds: max(0, seconds), preferredTimescale: 600))
    case "stop": closePlayer()

    default: result(FlutterMethodNotImplemented); return
    }
    result(nil)
  }
  private func activate() throws { try AVAudioSession.sharedInstance().setActive(true) }
  // The presenting Flutter controller also calls this after returning from
  // a full-screen modal. This recovers if AVKit skips its fullscreen callback.
  func reconcilePresentation() {
    guard let nativeController = controller, !pipActive,
          nativeController.presentingViewController == nil, !nativeController.isBeingPresented else { return }
    closePlayer()
  }
  private func closePlayer(failed: Bool = false) {
    guard let nativeController = controller else { return }
    let position = finite(player.currentTime().seconds)
    layerObservation = nil
    controller = nil
    pipActive = false
    stop()
    nativeController.player = nil
    if nativeController.presentingViewController == nil {
      emit(["type": "closed", "position": position, "failed": failed])
    } else {
      nativeController.presentingViewController?.dismiss(animated: true) { [weak self] in
        self?.emit(["type": "closed", "position": position, "failed": failed])
      }
    }
  }
  private func stop() {
    wantsPlayback = false
    resumeAfterInterruption = false
    openTimeout?.cancel()
    itemObservations.removeAll()
    player.pause()
    controller?.player = nil
    player.replaceCurrentItem(with: nil)
    info = [:]
    remoteTargets.forEach { $0.0.isEnabled = false }
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
  private func fail() {
    wantsPlayback = false
    resumeAfterInterruption = false
    openTimeout?.cancel()
    player.pause()
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    // AVFoundation errors can contain credential-bearing URLs.
    emit(["type": "state", "state": "failed", "message": "Native playback failed", "beforeFirstFrame": !firstFrame])
    guard let nativeController = controller else { return }
    if quietFailure && !firstFrame {
      // The app has another way to open this channel; no alert in between.
      let close = { [weak self, weak nativeController] in
        guard let self = self, let nativeController = nativeController,
              self.controller === nativeController else { return }
        self.closePlayer(failed: true)
      }
      if let transition = nativeController.transitionCoordinator {
        transition.animate(alongsideTransition: nil) { _ in close() }
      } else { close() }
      return
    }
    let showError = { [weak self, weak nativeController] in
      guard let self = self, let nativeController = nativeController,
            self.controller === nativeController, nativeController.presentedViewController == nil else { return }
      let alert = UIAlertController(title: "Cannot Play Video",
        message: self.info[MPNowPlayingInfoPropertyIsLiveStream] as? Bool == true
          ? "Apple’s player could not play this provider format. Try another feed for this channel."
          : "Apple’s player could not play this format. Open an existing file in Media to prepare MP4, or use Download for a new copy.", preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "Close", style: .default) { [weak self] _ in self?.closePlayer() })
      nativeController.present(alert, animated: true)
    }
    if let transition = nativeController.transitionCoordinator {
      transition.animate(alongsideTransition: nil) { _ in showError() }
    } else { showError() }
  }
  private func reportState() {
    guard player.currentItem != nil else { return }
    let state: String
    switch player.timeControlStatus {
    case .playing: state = "playing"
    case .waitingToPlayAtSpecifiedRate: state = "buffering"
    default: state = "paused"
    }
    if state == "playing" { wantsPlayback = true }
    if state == "paused" && UIApplication.shared.applicationState == .active && !resumeAfterInterruption {
      wantsPlayback = false
    }
    emit(["type": "state", "state": state])
    tick()
  }
  private func finite(_ value: Double) -> Double { value.isFinite ? max(0, value) : 0 }
  private func tick() {
    guard player.currentItem != nil else { return }
    let position = finite(player.currentTime().seconds)
    // Audio-only HLS has no ready-for-display video layer. Advancing playback
    // is also a valid successful start and must cancel the open timeout.
    if !firstFrame && videoExpected == false && player.timeControlStatus == .playing && position > 0 {
      firstFrame = true
      openTimeout?.cancel()
      emit(["type": "firstFrame"])
    }
    let duration = finite(player.currentItem?.duration.seconds ?? 0)
    emit(["type": "position", "position": position, "duration": duration])
    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
    info[MPMediaItemPropertyPlaybackDuration] = duration
    info[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
  }
  private func setNowPlaying(_ args: [String: Any]) {
    remoteTargets.forEach { $0.0.isEnabled = true }
    info = [MPMediaItemPropertyTitle: args["title"] as? String ?? "brenTV",
            MPNowPlayingInfoPropertyIsLiveStream: args["isLive"] as? Bool ?? false,
            MPMediaItemPropertyPlaybackDuration: args["duration"] as? Double ?? 0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: args["position"] as? Double ?? 0,
            MPNowPlayingInfoPropertyPlaybackRate: args["rate"] as? Double ?? 0]
    let vod = !(args["isLive"] as? Bool ?? false)
    let commands = MPRemoteCommandCenter.shared()
    commands.skipForwardCommand.isEnabled = vod
    commands.skipBackwardCommand.isEnabled = vod
    commands.changePlaybackPositionCommand.isEnabled = vod
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
  }
  private func performRemote(_ name: String, _ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
    guard player.currentItem != nil else { return .noSuchContent }
    switch name {
    case "play":
      do { try activate(); wantsPlayback = true; player.play() } catch { return .commandFailed }
    case "pause": wantsPlayback = false; resumeAfterInterruption = false; player.pause()
    case "toggle":
      if player.timeControlStatus != .paused { wantsPlayback = false; resumeAfterInterruption = false; player.pause() }
      else { do { try activate(); wantsPlayback = true; player.play() } catch { return .commandFailed } }
    case "seek":
      guard let seek = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
      player.seek(to: CMTime(seconds: max(0, seek.positionTime), preferredTimescale: 600))
    case "skipForward", "skipBackward":
      let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 15
      let seconds = finite(player.currentTime().seconds) + (name == "skipForward" ? interval : -interval)
      player.seek(to: CMTime(seconds: max(0, seconds), preferredTimescale: 600))
    default: return .commandFailed
    }
    // The native action works even while Flutter is suspended. State events
    // synchronize the route when its isolate is running again.
    reportState()
    return .success
  }
  private func installRemoteCommands() {
    let c = MPRemoteCommandCenter.shared()
    let commands: [(MPRemoteCommand, String)] = [(c.playCommand, "play"), (c.pauseCommand, "pause"),
      (c.togglePlayPauseCommand, "toggle"), (c.skipForwardCommand, "skipForward"),
      (c.skipBackwardCommand, "skipBackward"), (c.changePlaybackPositionCommand, "seek")]
    c.nextTrackCommand.isEnabled = false
    c.previousTrackCommand.isEnabled = false
    c.skipForwardCommand.preferredIntervals = [15]
    c.skipBackwardCommand.preferredIntervals = [15]
    for (command, name) in commands {
      command.isEnabled = false
      let target = command.addTarget { [weak self] event in
        guard let self = self else { return .noSuchContent }
        if Thread.isMainThread { return self.performRemote(name, event) }
        return DispatchQueue.main.sync { self.performRemote(name, event) }
      }
      remoteTargets.append((command, target))
    }
  }
  private func interrupted(_ note: Notification) {
    guard let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt else { return }
    if type == AVAudioSession.InterruptionType.began.rawValue {
      resumeAfterInterruption = wantsPlayback
      player.pause()
      reportState()
    } else {
      let options = AVAudioSession.InterruptionOptions(rawValue: note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
      if resumeAfterInterruption && wantsPlayback && player.currentItem != nil && options.contains(.shouldResume) {
        do { try activate(); player.play(); reportState() } catch { fail() }
      }
      resumeAfterInterruption = false
    }
  }
  private func detachForBackground() {
    guard UIApplication.shared.applicationState == .background, !pipActive else { return }
    if backgroundAudio {
      controller?.player = nil
      openTimeout?.cancel()
      if wantsPlayback && !resumeAfterInterruption {
        do { try activate(); player.play() } catch { fail() }
      }
    } else { player.pause() }
  }
  private func background() {
    // AVKit owns automatic PiP; give its transition time before detaching video.
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.detachForBackground() }
  }
  func playerViewController(_ playerViewController: AVPlayerViewController,
      willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
    coordinator.animate(alongsideTransition: nil) { [weak self] transition in
      guard let self = self, !transition.isCancelled, !self.pipActive,
            self.controller === playerViewController else { return }
      self.closePlayer()
    }
  }
  func playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart(_ playerViewController: AVPlayerViewController) -> Bool {
    return true
  }
  func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
    pipActive = true
  }
  func playerViewControllerDidStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
    emit(["type": "pip", "active": true, "possible": true])
  }
  func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
    pipActive = false
    emit(["type": "pip", "active": false, "possible": true])
    if playerViewController.presentingViewController == nil {
      closePlayer()
    } else { detachForBackground() }
  }
  func playerViewController(_ playerViewController: AVPlayerViewController,
      failedToStartPictureInPictureWithError error: Error) {
    pipActive = false
    detachForBackground()
    emit(["type": "pip", "active": false, "possible": false])
  }
  func playerViewController(_ playerViewController: AVPlayerViewController,
      restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
    guard controller === playerViewController else { completionHandler(false); return }
    playerViewController.player = player
    if playerViewController.presentingViewController != nil {
      completionHandler(true)
    } else if let parent = parentController, parent.presentedViewController == nil {
      parent.present(playerViewController, animated: true) { completionHandler(true) }
    } else { completionHandler(false) }
  }
  deinit {
    if let timer = timer { player.removeTimeObserver(timer) }
    notifications.forEach { NotificationCenter.default.removeObserver($0) }
    remoteTargets.forEach { $0.0.removeTarget($0.1) }
    openTimeout?.cancel()
  }
}

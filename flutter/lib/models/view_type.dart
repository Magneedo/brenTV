// IDs are persisted and sent to Rust. Append destinations; never reorder them.
enum ViewType {
  all,
  categories,
  favorites,
  history,
  settings,
  localMedia,
  recordings,
  downloads,
}

String viewTypeToString(ViewType view) => switch (view) {
  ViewType.all => 'All',
  ViewType.categories => 'Categories',
  ViewType.favorites => 'Favorites',
  ViewType.history => 'History',
  ViewType.settings => 'Settings',
  ViewType.localMedia => 'Media',
  ViewType.recordings => 'DVR',
  ViewType.downloads => 'Media',
};

import 'package:brentv/categories_view.dart';
import 'package:brentv/refresh_stats.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:brentv/models/source.dart';
import 'package:brentv/models/source_type.dart';
import 'package:brentv/error.dart';
import 'package:brentv/native_bridge.dart';

class EditDialog extends StatefulWidget {
  final Source source;
  final AsyncCallback afterSave;
  final BuildContext parentContext;
  const EditDialog({
    super.key,
    required this.source,
    required this.afterSave,
    required this.parentContext,
  });

  @override
  State<EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<EditDialog> {
  late bool importLive = widget.source.importLive;
  late bool importMovies = widget.source.importMovies;
  late bool importSeries = widget.source.importSeries;
  final _formKey = GlobalKey<FormBuilderState>();

  Source editedSource() {
    final source = widget.source;
    return Source(
      id: source.id,
      name: source.name,
      sourceType: source.sourceType,
      url: _formKey.currentState?.value['url'],
      username: source.sourceType == SourceType.xtream
          ? _formKey.currentState?.value['username']
          : source.username,
      password: source.sourceType == SourceType.xtream
          ? _formKey.currentState?.value['password']
          : source.password,
      enabled: source.enabled,
      urlOrigin: source.urlOrigin,
      userAgent: source.userAgent,
      streamUserAgent: source.streamUserAgent,
      importLive: importLive,
      importMovies: importMovies,
      importSeries: importSeries,
      epgUrl: source.sourceType == SourceType.xtream
          ? source.epgUrl
          : (_formKey.currentState?.value['epgUrl'] as String?)?.trim(),
    );
  }

  Future<void> chooseCategories() async {
    if (!_formKey.currentState!.saveAndValidate()) return;
    final updated = editedSource();
    final saved = await Error.tryAsyncNoLoading(
      () => NativeBridge.instance.updateSource(updated),
      context,
    );
    if (!mounted || !saved.success) return;
    // This action explicitly saves the form; cancelling the category screen
    // cancels category edits only.
    await widget.afterSave();
    if (!mounted) return;
    Navigator.pop(context);
    if (widget.parentContext.mounted) {
      await Navigator.push(
        widget.parentContext,
        MaterialPageRoute(builder: (_) => CategoriesView(source: updated)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: AlertDialog(
          title: Text("Edit source ${widget.source.name}"),
          actions: [
            TextButton(
              onPressed: () async {
                if (!_formKey.currentState!.saveAndValidate()) {
                  return;
                }
                final source = widget.source;
                final changed =
                    importLive != source.importLive ||
                    importMovies != source.importMovies ||
                    importSeries != source.importSeries;
                final updated = editedSource();
                final result = await Error.tryAsyncNoLoading(
                  () => NativeBridge.instance.updateSource(updated),
                  widget.parentContext,
                );
                if (!result.success) return;
                if (!context.mounted) return;
                Navigator.of(context).pop();
                if (changed && widget.parentContext.mounted) {
                  await offerRefresh(widget.parentContext, updated);
                }
                await widget.afterSave();
              },
              child: const Text("Save"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
          ],
          content: FormBuilder(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Import live'),
                  value: importLive,
                  onChanged: (v) => setState(() => importLive = v),
                ),
                SwitchListTile(
                  title: const Text('Import movies'),
                  value: importMovies,
                  onChanged: (v) => setState(() => importMovies = v),
                ),
                SwitchListTile(
                  title: const Text('Import series'),
                  value: importSeries,
                  onChanged: (v) => setState(() => importSeries = v),
                ),
                TextButton(
                  onPressed: chooseCategories,
                  child: const Text('Save and choose categories…'),
                ),

                const SizedBox(height: 15),
                FormBuilderTextField(
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  initialValue: widget.source.url,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(),
                  ]),
                  decoration: const InputDecoration(
                    labelText: 'Url',
                    prefixIcon: Icon(Icons.link),
                    border: OutlineInputBorder(),
                  ),
                  name: 'url',
                ),
                if (widget.source.sourceType != SourceType.xtream)
                  FormBuilderTextField(
                    name: 'epgUrl',
                    initialValue: widget.source.epgUrl,
                    decoration: const InputDecoration(
                      labelText: 'XMLTV guide URL (optional)',
                      helperText:
                          'Enable XMLTV in Settings; channels match by tvg-id',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      final uri = Uri.tryParse(value.trim());
                      return uri != null &&
                              ['http', 'https', 'file'].contains(uri.scheme)
                          ? null
                          : 'Use an HTTP, HTTPS or file URL';
                    },
                  ),
                Visibility(
                  visible: widget.source.sourceType == SourceType.xtream,
                  child: const SizedBox(height: 30),
                ),
                Visibility(
                  visible: widget.source.sourceType == SourceType.xtream,
                  child: FormBuilderTextField(
                    textInputAction: TextInputAction.next,
                    initialValue: widget.source.username,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(),
                    ]),
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.account_circle),
                      border: OutlineInputBorder(),
                    ),
                    name: 'username',
                  ),
                ),
                Visibility(
                  visible: widget.source.sourceType == SourceType.xtream,
                  child: const SizedBox(height: 30),
                ),
                Visibility(
                  visible: widget.source.sourceType == SourceType.xtream,
                  child: FormBuilderTextField(
                    textInputAction: TextInputAction.next,
                    initialValue: widget.source.password,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(),
                    ]),
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.password),
                      border: OutlineInputBorder(),
                    ),
                    name: 'password',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

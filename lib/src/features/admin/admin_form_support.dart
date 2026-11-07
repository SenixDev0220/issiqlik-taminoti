part of 'admin_panel_screen.dart';

/// Controllers and save state belong to the route, not the launching screen.
/// They remain alive through the closing animation and are disposed with it.
abstract class _AdminFormState<T extends ConsumerStatefulWidget> extends ConsumerState<T> {
  final formKey = GlobalKey<FormState>();
  final _controllers = <TextEditingController>[];
  bool saving = false;

  TextEditingController controller([Object? value]) {
    final result = TextEditingController(text: value == null || value == 0 ? '' : '$value');
    _controllers.add(result);
    return result;
  }

  Future<void> submit(Future<void> Function() save) async {
    if (saving || !_canManage(ref.read(currentUserProvider))) return;
    if (formKey.currentState?.validate() != true) return;
    setState(() => saving = true);
    final saved = await runUiAction(context, ref, save);
    if (!mounted) return;
    setState(() => saving = false);
    if (saved) Navigator.pop(context);
  }

  Widget field(TextEditingController controller, String label, {
    bool number = false,
    int lines = 1,
    bool required = false,
  }) {
    final l = ref.watch(l10nProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : (lines > 1 ? TextInputType.multiline : TextInputType.text),
        maxLines: lines,
        decoration: InputDecoration(labelText: required ? '$label *' : label),
        validator: required ? (value) => value == null || value.trim().isEmpty ? l.fieldRequired : null : null,
      ),
    );
  }

  Widget sheet({required String title, required List<Widget> fields, required VoidCallback onSave}) {
    final l = ref.watch(l10nProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Form(
          key: formKey,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              children: [
                Center(child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.inkFaintFor(context).withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                )),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Expanded(child: ListView(controller: scrollController, children: fields)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving ? null : onSave,
                    child: saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l.save),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}

class _ReferenceNotice extends StatelessWidget {
  const _ReferenceNotice({required this.l});

  final AppL10n l;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: GlassCard(
      tint: AppTheme.warning,
      child: Text(l.archivedReferenceNotice),
    ),
  );
}

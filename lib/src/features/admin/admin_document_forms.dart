part of 'admin_panel_screen.dart';

class _InstructionForm extends ConsumerStatefulWidget {
  const _InstructionForm({this.existing});
  final Instruction? existing;

  @override
  ConsumerState<_InstructionForm> createState() => _InstructionFormState();
}

class _InstructionFormState extends _AdminFormState<_InstructionForm> {
  late final String _id;
  late final DateTime _createdAt;
  late final TextEditingController _title, _category, _body;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _id = existing?.id ?? _fb.newDocumentId('instructions');
    _createdAt = existing?.createdAt ?? DateTime.now();
    _title = controller(existing?.title);
    _category = controller(existing?.category);
    _body = controller(existing?.body);
  }

  Future<void> _save() => submit(() {
    final existing = widget.existing;
    final instruction = Instruction(
      id: _id,
      title: _title.text.trim(),
      category: _category.text.trim(),
      body: _body.text.trim(),
      version: existing?.version ?? '1.0',
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
      authorId: existing?.authorId ?? '',
      urgency: existing?.urgency ?? InstructionUrgency.normal,
      boilerHouseIds: existing?.boilerHouseIds ?? const [],
      equipmentTypes: existing?.equipmentTypes ?? const [],
    );
    return existing == null ? _fb.addInstruction(instruction) : _fb.updateInstruction(instruction);
  });

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final activeIds = ref.watch(boilerHouseListProvider).map((house) => house.id).toSet();
    final unavailableReference = widget.existing?.boilerHouseIds.any((id) => !activeIds.contains(id)) ?? false;
    return sheet(
      title: widget.existing == null ? l.formNewInstruction : l.formEdit,
      onSave: _save,
      fields: [
        if (unavailableReference) _ReferenceNotice(l: l),
        field(_title, l.changeLogHeading, required: true),
        field(_category, l.formCategory),
        field(_body, l.formText, lines: 5),
      ],
    );
  }
}

class _DrawingForm extends ConsumerStatefulWidget {
  const _DrawingForm({this.existing});
  final Drawing? existing;

  @override
  ConsumerState<_DrawingForm> createState() => _DrawingFormState();
}

class _DrawingFormState extends _AdminFormState<_DrawingForm> {
  late final String _id;
  late final DateTime _addedAt;
  late final TextEditingController _title, _number, _category, _description;
  String? _houseId;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _id = existing?.id ?? _fb.newDocumentId('drawings');
    _addedAt = existing?.addedAt ?? DateTime.now();
    _title = controller(existing?.title);
    _number = controller(existing?.number);
    _category = controller(existing?.category);
    _description = controller(existing?.description);
    _houseId = existing?.boilerHouseId;
  }

  Future<void> _save() => submit(() {
    if (!ref.read(boilerHouseListProvider).any((house) => house.id == _houseId)) {
      throw StateError('inactive-reference');
    }
    final existing = widget.existing;
    final drawing = Drawing(
      id: _id,
      title: _title.text.trim(),
      number: _number.text.trim(),
      category: _category.text.trim(),
      description: _description.text.trim(),
      boilerHouseId: _houseId!,
      filePath: existing?.filePath ?? '',
      authorId: existing?.authorId ?? '',
      addedAt: _addedAt,
    );
    return existing == null ? _fb.addDrawing(drawing) : _fb.updateDrawing(drawing);
  });

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final houses = ref.watch(boilerHouseListProvider);
    final available = houses.any((house) => house.id == _houseId);
    final unavailableReference = _houseId != null && !available;
    return sheet(
      title: widget.existing == null ? l.formNewDrawing : l.formEdit,
      onSave: _save,
      fields: [
        if (unavailableReference) _ReferenceNotice(l: l),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            // Keep a disabled fallback item when an archived selection disappears
            // while the sheet is open; FormField's state can still hold that ID.
            initialValue: _houseId,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.navBoilerhouses),
            items: [
              if (unavailableReference)
                DropdownMenuItem(value: _houseId, enabled: false, child: Text(l.archivedReferenceLabel)),
              ...houses.map((house) => DropdownMenuItem(
                value: house.id,
                child: Text(house.name, maxLines: 2, overflow: TextOverflow.ellipsis),
              )),
            ],
            onChanged: (value) => setState(() => _houseId = value),
            validator: (value) => houses.any((house) => house.id == value) ? null : l.activeReferenceRequired,
          ),
        ),
        field(_title, l.changeLogHeading, required: true),
        field(_number, l.formNumber),
        field(_category, l.formCategory),
        field(_description, l.changeLogDescription, lines: 3),
      ],
    );
  }
}

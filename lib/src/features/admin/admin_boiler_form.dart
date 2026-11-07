part of 'admin_panel_screen.dart';

class _BoilerForm extends ConsumerStatefulWidget {
  const _BoilerForm({this.existing});
  final BoilerHouse? existing;

  @override
  ConsumerState<_BoilerForm> createState() => _BoilerFormState();
}

class _BoilerFormState extends _AdminFormState<_BoilerForm> {
  late final String _id;
  late final TextEditingController _name, _address, _year, _modernization, _area,
      _workers, _capacity, _load, _consumers, _pipeline, _phone, _electricity,
      _gas, _heat, _location;
  late String _district;

  static const _districts = [
    'Урганч шаҳар', 'Шовот', 'Хонка', 'Қўшкўпир', 'Хазорасп', 'Тупроккала',
    'Янгиариқ', 'Урганч туман', 'Боғот', 'Янгибозор', 'Гурлан', 'Хива',
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _id = existing?.id ?? _fb.newDocumentId('boilerhouses');
    _name = controller(existing?.name);
    _address = controller(existing?.address);
    _year = controller(existing?.yearBuilt);
    _modernization = controller(existing?.modernizationYear);
    _area = controller(existing?.totalArea);
    _workers = controller(existing?.workersCount);
    _capacity = controller(existing?.installedCapacity);
    _load = controller(existing?.connectedLoad);
    _consumers = controller(existing?.consumers);
    _pipeline = controller(existing?.pipelineLength);
    _phone = controller(existing?.dispatchPhone);
    _electricity = controller(existing?.annualElectricity);
    _gas = controller(existing?.annualGas);
    _heat = controller(existing?.annualHeatProduction);
    _location = controller(existing?.locationUrl);
    _district = existing?.district ?? _districts.first;
  }

  Future<void> _save() => submit(() {
    final existing = widget.existing;
    final house = BoilerHouse(
      id: _id,
      name: _name.text.trim(),
      district: _district,
      address: _address.text.trim(),
      yearBuilt: int.tryParse(_year.text) ?? 0,
      modernizationYear: int.tryParse(_modernization.text) ?? 0,
      totalArea: double.tryParse(_area.text) ?? 0,
      workersCount: int.tryParse(_workers.text) ?? 0,
      installedCapacity: double.tryParse(_capacity.text) ?? 0,
      connectedLoad: double.tryParse(_load.text) ?? 0,
      consumers: _consumers.text.trim(),
      pipelineLength: double.tryParse(_pipeline.text) ?? 0,
      dispatchPhone: _phone.text.trim(),
      annualElectricity: double.tryParse(_electricity.text) ?? 0,
      annualGas: double.tryParse(_gas.text) ?? 0,
      annualHeatProduction: double.tryParse(_heat.text) ?? 0,
      locationUrl: _location.text.trim(),
      operatorsCount: existing?.operatorsCount ?? 0,
      annualWater: existing?.annualWater ?? 0,
      aboveGroundPipeline: existing?.aboveGroundPipeline ?? 0,
      belowGroundPipeline: existing?.belowGroundPipeline ?? 0,
      defects: existing?.defects ?? '',
      status: existing?.status ?? BoilerHouseStatus.operating,
    );
    return existing == null ? _fb.addBoilerhouse(house) : _fb.updateBoilerhouse(house);
  });

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    // Keep legacy/custom districts editable instead of asserting in a dropdown.
    final districts = {..._districts, if (_district.isNotEmpty) _district};
    return sheet(
      title: widget.existing == null ? l.formNewBoilerhouse : l.formEdit,
      onSave: _save,
      fields: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: districts.contains(_district) ? _district : null,
            decoration: InputDecoration(labelText: '${l.formDistrict} *'),
            items: districts.map((district) => DropdownMenuItem(value: district, child: Text(district))).toList(),
            onChanged: (value) => setState(() => _district = value ?? _district),
            validator: (value) => value == null || value.isEmpty ? l.fieldRequired : null,
          ),
        ),
        field(_name, l.formName, required: true),
        field(_address, l.formAddress),
        ResponsiveWrap(children: [field(_year, l.fieldYearBuiltDetail, number: true), field(_modernization, l.fieldModernization, number: true)]),
        ResponsiveWrap(children: [field(_area, l.formArea, number: true), field(_workers, l.fieldWorkers, number: true)]),
        ResponsiveWrap(children: [field(_capacity, l.formCapacity, number: true), field(_load, l.formLoad, number: true)]),
        field(_consumers, l.fieldConsumers),
        ResponsiveWrap(children: [field(_pipeline, l.formPipeline, number: true), field(_phone, l.formPhone)]),
        ResponsiveWrap(children: [field(_electricity, l.formElectricity, number: true), field(_gas, l.formGas, number: true)]),
        field(_heat, l.formHeat, number: true),
        field(_location, l.formLocationUrl),
      ],
    );
  }
}

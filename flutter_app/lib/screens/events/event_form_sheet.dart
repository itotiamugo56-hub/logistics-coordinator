import 'package:flutter/material.dart';
import '../../constants/motion_tokens.dart';
import '../../widgets/crystal_button.dart';
import '../events/events_screen.dart';

class EventFormSheet extends StatefulWidget {
  final Function(Event) onSubmit;
  final VoidCallback onCancel;
  
  const EventFormSheet({
    super.key,
    required this.onSubmit,
    required this.onCancel,
  });
  
  @override
  State<EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends State<EventFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _selectedDate;
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(MotionTokens.spacingLG),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create Event',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: MotionTokens.spacingLG),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Event Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: MotionTokens.spacingMD),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: MotionTokens.spacingMD),
            ListTile(
              title: const Text('Event Date'),
              subtitle: Text(_selectedDate == null 
                  ? 'Not set' 
                  : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectDate,
            ),
            const SizedBox(height: MotionTokens.spacingXL),
            Row(
              children: [
                Expanded(
                  child: CrystalButton(
                    label: 'Cancel',
                    onPressed: widget.onCancel,
                    variant: CrystalButtonVariant.outlined,
                  ),
                ),
                const SizedBox(width: MotionTokens.spacingMD),
                Expanded(
                  child: CrystalButton(
                    label: 'Create',
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }
  
  void _submit() {
    if (_formKey.currentState!.validate() && _selectedDate != null) {
      final event = Event(
        id: '', // Will be generated on server
        name: _nameController.text,
        eventDate: _selectedDate!,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      );
      widget.onSubmit(event);
    }
  }
}

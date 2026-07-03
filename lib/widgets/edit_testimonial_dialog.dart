import 'package:flutter/material.dart';

class EditTestimonialDialog extends StatefulWidget {
  final Map<String, dynamic>? testimonial; // null for new entry

  const EditTestimonialDialog({super.key, this.testimonial});

  @override
  State<EditTestimonialDialog> createState() => _EditTestimonialDialogState();
}

class _EditTestimonialDialogState extends State<EditTestimonialDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _textController;
  late TextEditingController _authorController;
  late TextEditingController _locationController;
  late TextEditingController _initialsController;

  @override
  void initState() {
    super.initState();
    final t = widget.testimonial;
    _textController = TextEditingController(text: t?['text'] ?? '');
    _authorController = TextEditingController(text: t?['author'] ?? '');
    _locationController = TextEditingController(text: t?['location'] ?? '');
    _initialsController = TextEditingController(text: t?['initials'] ?? '');
  }

  @override
  void dispose() {
    _textController.dispose();
    _authorController.dispose();
    _locationController.dispose();
    _initialsController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop({
      'text': _textController.text.trim(),
      'author': _authorController.text.trim(),
      'location': _locationController.text.trim(),
      'initials': _initialsController.text.trim().toUpperCase(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.testimonial == null;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isNew ? 'Add Testimonial' : 'Edit Testimonial',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _textController,
                  decoration: const InputDecoration(
                    labelText: 'Testimonial text',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Please enter the testimonial text' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _authorController,
                  decoration: const InputDecoration(
                    labelText: 'Author name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Please enter an author name' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Please enter a location' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _initialsController,
                  decoration: const InputDecoration(
                    labelText: 'Avatar initials (2 letters)',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 2,
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Please enter initials' : null,
                ),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(isNew ? 'Add' : 'Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

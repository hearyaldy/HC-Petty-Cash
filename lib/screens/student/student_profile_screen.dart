import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/student_timesheet.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_storage_service.dart';
import '../../utils/responsive_helper.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _courseController = TextEditingController();
  final _yearLevelController = TextEditingController();
  final _languageController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  StudentProfile? _profile;
  String? _photoUrl;
  Uint8List? _pickedBytes;
  File? _pickedFile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _courseController.dispose();
    _yearLevelController.dispose();
    _languageController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No authenticated user.')));
      }
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('student_profiles')
          .doc(user.id)
          .get();

      if (doc.exists) {
        _profile = StudentProfile.fromFirestore(doc);
        _phoneController.text = _profile?.phoneNumber ?? '';
        _courseController.text = _profile?.course ?? '';
        _yearLevelController.text = _profile?.yearLevel ?? '';
        _languageController.text = _profile?.language ?? '';
        _photoUrl = _profile?.photoUrl;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
    );
    if (result == null) return;

    if (kIsWeb) {
      final bytes = await result.readAsBytes();
      setState(() {
        _pickedBytes = bytes;
        _pickedFile = null;
      });
    } else {
      setState(() {
        _pickedFile = File(result.path);
        _pickedBytes = null;
      });
    }
  }

  Future<void> _saveProfile() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No authenticated user.')));
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    String? photoUrl = _photoUrl;

    try {
      // Upload new photo if picked
      if (_pickedBytes != null || _pickedFile != null) {
        final storage = FirebaseStorageService();
        if (kIsWeb && _pickedBytes != null) {
          photoUrl = await storage.uploadAttachmentFromBytes(
            transactionId: user.id,
            bytes: _pickedBytes!,
            fileName: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
        } else if (_pickedFile != null) {
          photoUrl = await storage.uploadAttachment(
            transactionId: user.id,
            file: _pickedFile!,
          );
        }
      }

      final data = {
        'userId': user.id,
        'studentNumber': _profile?.studentNumber ?? '',
        'phoneNumber': _phoneController.text.trim(),
        'course': _courseController.text.trim(),
        'yearLevel': _yearLevelController.text.trim(),
        'language': _languageController.text.trim(),
        'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('student_profiles')
          .doc(user.id)
          .set(data, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
      }

      setState(() {
        _photoUrl = photoUrl;
        _pickedBytes = null;
        _pickedFile = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  ImageProvider _buildAvatarImage() {
    if (_pickedBytes != null) {
      return MemoryImage(_pickedBytes!);
    }
    if (_pickedFile != null) {
      return FileImage(_pickedFile!);
    }
    if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      return NetworkImage(_photoUrl!);
    }
    return const AssetImage('assets/images/app_icon.png');
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        leading: IconButton(
          icon: const Icon(Icons.home_outlined),
          onPressed: () => context.go('/student-dashboard'),
        ),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveProfile,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save, color: Colors.white),
            label: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveContainer(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildHeader(user?.name ?? 'Student', user?.email ?? ''),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: _buildFormCard(user),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isSaving ? null : _saveProfile,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _isSaving ? 'Saving...' : 'Save Profile',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(String name, String email) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.orange.shade400, Colors.orange.shade600],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.shade200,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundImage: _buildAvatarImage(),
            backgroundColor: Colors.white.withOpacity(0.2),
            child:
                (_photoUrl == null &&
                    _pickedBytes == null &&
                    _pickedFile == null)
                ? const Icon(Icons.person, size: 42, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.orange.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: _isSaving ? null : _pickPhoto,
            icon: const Icon(Icons.photo_camera),
            label: const Text('Change Photo'),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(dynamic user) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile Details',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: user?.name ?? '',
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: user?.email ?? '',
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _courseController,
                decoration: const InputDecoration(
                  labelText: 'Course / Program',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _yearLevelController,
                decoration: const InputDecoration(
                  labelText: 'Year Level',
                  prefixIcon: Icon(Icons.stairs_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _languageController,
                decoration: const InputDecoration(
                  labelText: 'Preferred Language',
                  prefixIcon: Icon(Icons.language_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

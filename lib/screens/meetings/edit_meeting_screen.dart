import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/meeting.dart';
import '../../services/adcom_agenda_service.dart';
import '../../services/meeting_service.dart';
import '../../utils/responsive_helper.dart';

class EditMeetingScreen extends StatefulWidget {
  final String meetingId;

  const EditMeetingScreen({super.key, required this.meetingId});

  @override
  State<EditMeetingScreen> createState() => _EditMeetingScreenState();
}

class _EditMeetingScreenState extends State<EditMeetingScreen> {
  static const String _externalMemberValue = '__external__';
  final MeetingService _meetingService = MeetingService();
  final AdcomAgendaService _adcomAgendaService = AdcomAgendaService();
  final _formKey = GlobalKey<FormState>();

  Meeting? _meeting;
  String _meetingType = 'adcom';
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _virtualLinkController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);

  String? _chairpersonId;
  String? _chairpersonName;
  String? _secretaryId;
  String? _secretaryName;

  final List<MeetingMember> _invitedMembers = [];
  bool _isLoading = true;
  bool _isSaving = false;

  List<Map<String, dynamic>> _availableUsers = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadMeeting();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _virtualLinkController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadMeeting() async {
    setState(() => _isLoading = true);
    try {
      final meeting = await _meetingService.getMeeting(widget.meetingId);
      if (meeting == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Meeting not found')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final meetingDateTime = meeting.dateTime;
      setState(() {
        _meeting = meeting;
        _meetingType = meeting.type;
        _titleController.text = meeting.title;
        _locationController.text = meeting.location ?? '';
        _virtualLinkController.text = meeting.virtualLink ?? '';
        _notesController.text = meeting.notes ?? '';
        _selectedDate = DateTime(
          meetingDateTime.year,
          meetingDateTime.month,
          meetingDateTime.day,
        );
        _selectedTime = TimeOfDay(
          hour: meetingDateTime.hour,
          minute: meetingDateTime.minute,
        );
        _chairpersonId = meeting.chairpersonId;
        _chairpersonName = meeting.chairpersonName;
        _secretaryId = meeting.secretaryId;
        _secretaryName = meeting.secretaryName;
        _invitedMembers
          ..clear()
          ..addAll(meeting.invitedMembers);
        _isLoading = false;
      });

      _normalizeRoleSelections();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading meeting: $e')),
        );
      }
    }
  }

  Future<void> _loadUsers() async {
    try {
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: ['admin', 'manager', 'finance'])
          .get();

      setState(() {
        _availableUsers = usersQuery.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? 'Unknown',
            'email': data['email'] ?? '',
            'role': data['role'] ?? '',
          };
        }).toList();
      });

      _normalizeRoleSelections();
    } catch (e) {
      debugPrint('Error loading users: $e');
    }
  }

  void _normalizeRoleSelections() {
    if (_meeting == null) return;
    if (_availableUsers.isEmpty) {
      setState(() {
        if (_chairpersonId == null && (_chairpersonName ?? '').isNotEmpty) {
          _chairpersonId = _externalMemberValue;
        }
        if (_secretaryId == null && (_secretaryName ?? '').isNotEmpty) {
          _secretaryId = _externalMemberValue;
        }
      });
      return;
    }

    bool hasUser(String? id) {
      if (id == null) return false;
      return _availableUsers.any((u) => u['id'] == id);
    }

    setState(() {
      if (_chairpersonId == null && (_chairpersonName ?? '').isNotEmpty) {
        _chairpersonId = _externalMemberValue;
      } else if (_chairpersonId != null && !hasUser(_chairpersonId)) {
        _chairpersonId = _externalMemberValue;
      }

      if (_secretaryId == null && (_secretaryName ?? '').isNotEmpty) {
        _secretaryId = _externalMemberValue;
      } else if (_secretaryId != null && !hasUser(_secretaryId)) {
        _secretaryId = _externalMemberValue;
      }
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _updateMeeting() async {
    if (!_formKey.currentState!.validate()) return;
    if (_meeting == null) return;

    setState(() => _isSaving = true);

    try {
      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final updatedMeeting = _meeting!.copyWith(
        type: _meetingType,
        title: _titleController.text.trim(),
        dateTime: dateTime,
        location: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        virtualLink: _virtualLinkController.text.trim().isNotEmpty
            ? _virtualLinkController.text.trim()
            : null,
        chairpersonId: _chairpersonId == _externalMemberValue
            ? null
            : _chairpersonId,
        chairpersonName: _chairpersonName,
        secretaryId: _secretaryId == _externalMemberValue
            ? null
            : _secretaryId,
        secretaryName: _secretaryName,
        invitedMembers: List<MeetingMember>.from(_invitedMembers),
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        updatedAt: DateTime.now(),
        createdBy: _meeting!.createdBy,
      );

      await _meetingService.updateMeeting(updatedMeeting);

      if (updatedMeeting.agendaId != null &&
          updatedMeeting.agendaId!.isNotEmpty) {
        final agenda =
            await _adcomAgendaService.getAgendaById(updatedMeeting.agendaId!);
        if (agenda != null) {
          final meetingTime = DateFormat('h:mm a').format(dateTime);
          final updatedAgenda = agenda.copyWith(
            meetingDate: dateTime,
            meetingTime: meetingTime,
            location: updatedMeeting.location ?? '',
            updatedAt: DateTime.now(),
          );
          await _adcomAgendaService.updateAgenda(updatedAgenda);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meeting updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/meetings/${updatedMeeting.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating meeting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Edit Meeting'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _updateMeeting,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Save'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _meeting == null
              ? const Center(child: Text('Meeting not found'))
              : SafeArea(
                  child: SingleChildScrollView(
                    child: ResponsiveContainer(
                      child: Padding(
                        padding: ResponsiveHelper.getScreenPadding(context),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMeetingTypeSelector(),
                              const SizedBox(height: 16),
                              _buildBasicInfoSection(),
                              const SizedBox(height: 16),
                              _buildDateTimeSection(),
                              const SizedBox(height: 16),
                              _buildLocationSection(),
                              const SizedBox(height: 16),
                              _buildRolesSection(),
                              const SizedBox(height: 16),
                              _buildMembersSection(),
                              const SizedBox(height: 16),
                              _buildNotesSection(),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isSaving ? null : _updateMeeting,
                                  icon: const Icon(Icons.save),
                                  label: const Text('Save Changes'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildMeetingTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Meeting Type',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTypeOption(
                  'adcom',
                  'HC ADCOM',
                  'Administrative Committee',
                  Icons.business,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTypeOption(
                  'board',
                  'HC Board',
                  'Board Meeting',
                  Icons.account_balance,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption(
    String value,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    final isSelected = _meetingType == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _meetingType = value;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : Colors.grey[600],
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Meeting Title',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.title),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a meeting title';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Date & Time',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: _selectTime,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Time',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.access_time),
                    ),
                    child: Text(_selectedTime.format(context)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Location',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'Physical Location (optional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _virtualLinkController,
            decoration: const InputDecoration(
              labelText: 'Virtual Meeting Link (optional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.videocam),
              hintText: 'e.g., Zoom or Teams link',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRolesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Meeting Roles',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _chairpersonId,
            decoration: const InputDecoration(
              labelText: 'Chairperson',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            items: [
              ..._availableUsers.map((user) {
                return DropdownMenuItem<String>(
                  value: user['id'] as String,
                  child: Text(user['name'] as String),
                );
              }),
              DropdownMenuItem<String>(
                value: _externalMemberValue,
                child: Text(
                  _chairpersonId == _externalMemberValue &&
                          (_chairpersonName ?? '').isNotEmpty
                      ? 'External: $_chairpersonName'
                      : 'External member',
                ),
              ),
            ],
            onChanged: (value) async {
              setState(() {
                _chairpersonId = value;
              });
              if (value == _externalMemberValue) {
                final name = await _promptExternalMemberName('Chairperson');
                if (!mounted) return;
                setState(() {
                  if (name == null || name.trim().isEmpty) {
                    _chairpersonId = null;
                    _chairpersonName = null;
                  } else {
                    _chairpersonName = name.trim();
                  }
                });
              } else {
                setState(() {
                  _chairpersonName = _availableUsers
                      .firstWhere((u) => u['id'] == value)['name'] as String?;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _secretaryId,
            decoration: const InputDecoration(
              labelText: 'Secretary / Minutes Taker',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.edit_note),
            ),
            items: [
              ..._availableUsers.map((user) {
                return DropdownMenuItem<String>(
                  value: user['id'] as String,
                  child: Text(user['name'] as String),
                );
              }),
              DropdownMenuItem<String>(
                value: _externalMemberValue,
                child: Text(
                  _secretaryId == _externalMemberValue &&
                          (_secretaryName ?? '').isNotEmpty
                      ? 'External: $_secretaryName'
                      : 'External member',
                ),
              ),
            ],
            onChanged: (value) async {
              setState(() {
                _secretaryId = value;
              });
              if (value == _externalMemberValue) {
                final name = await _promptExternalMemberName('Secretary');
                if (!mounted) return;
                setState(() {
                  if (name == null || name.trim().isEmpty) {
                    _secretaryId = null;
                    _secretaryName = null;
                  } else {
                    _secretaryName = name.trim();
                  }
                });
              } else {
                setState(() {
                  _secretaryName = _availableUsers
                      .firstWhere((u) => u['id'] == value)['name'] as String?;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMembersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Invited Members',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _showMemberPicker,
                    icon: const Icon(Icons.people, size: 18),
                    label: const Text('Internal'),
                  ),
                  TextButton.icon(
                    onPressed: _showAddExternalMemberDialog,
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('External'),
                  ),
                ],
              ),
            ],
          ),
          if (_invitedMembers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No members added yet',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _invitedMembers.map((member) {
                final isExternal = member.oderId.startsWith('external_');
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: isExternal
                        ? Colors.orange.withValues(alpha: 0.2)
                        : Colors.indigo.withValues(alpha: 0.2),
                    child: Icon(
                      isExternal ? Icons.person_outline : Icons.person,
                      size: 16,
                      color: isExternal ? Colors.orange : Colors.indigo,
                    ),
                  ),
                  label: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(member.name),
                      if (isExternal && member.organization != null)
                        Text(
                          member.organization!,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () {
                    setState(() {
                      _invitedMembers.removeWhere(
                        (m) => m.oderId == member.oderId,
                      );
                    });
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Additional Notes (optional)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  void _showMemberPicker() {
    final selectedMembers = List<MeetingMember>.from(_invitedMembers);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.3,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Select Internal Members',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _invitedMembers.removeWhere(
                                  (m) => !m.oderId.startsWith('external_'),
                                );
                                _invitedMembers.addAll(
                                  selectedMembers.where(
                                    (m) => !m.oderId.startsWith('external_'),
                                  ),
                                );
                              });
                              Navigator.pop(bottomSheetContext);
                            },
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: _availableUsers.length,
                        itemBuilder: (context, index) {
                          final user = _availableUsers[index];
                          final isSelected = selectedMembers.any(
                            (m) => m.oderId == user['id'],
                          );
                          return CheckboxListTile(
                            value: isSelected,
                            title: Text(user['name'] as String),
                            subtitle: Text(user['email'] as String),
                            onChanged: (value) {
                              setBottomSheetState(() {
                                if (value == true) {
                                  selectedMembers.add(
                                    MeetingMember(
                                      oderId: user['id'] as String,
                                      name: user['name'] as String,
                                      email: user['email'] as String?,
                                      role: 'Member',
                                    ),
                                  );
                                } else {
                                  selectedMembers.removeWhere(
                                    (m) => m.oderId == user['id'],
                                  );
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showAddExternalMemberDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final organizationController = TextEditingController();
    final roleController = TextEditingController(text: 'Guest');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add External Member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: organizationController,
                  decoration: const InputDecoration(
                    labelText: 'Organization',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business),
                    hintText: 'e.g., GC, Union, etc.',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email (optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: roleController,
                  decoration: const InputDecoration(
                    labelText: 'Role in Meeting',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                    hintText: 'e.g., Guest, Observer, Presenter',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter the member name'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final externalId =
                    'external_${DateTime.now().millisecondsSinceEpoch}';
                setState(() {
                  _invitedMembers.add(
                    MeetingMember(
                      oderId: externalId,
                      name: nameController.text.trim(),
                      email: emailController.text.trim().isNotEmpty
                          ? emailController.text.trim()
                          : null,
                      role: roleController.text.trim().isNotEmpty
                          ? roleController.text.trim()
                          : 'Guest',
                      organization:
                          organizationController.text.trim().isNotEmpty
                              ? organizationController.text.trim()
                              : null,
                    ),
                  );
                });
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _promptExternalMemberName(String roleLabel) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('External $roleLabel'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

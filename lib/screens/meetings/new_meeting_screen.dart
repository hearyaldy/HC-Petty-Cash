import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/adcom_agenda.dart' as adcom;
import '../../models/meeting.dart';
import '../../providers/auth_provider.dart';
import '../../services/adcom_agenda_service.dart';
import '../../services/meeting_service.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';

class NewMeetingScreen extends StatefulWidget {
  final String? preselectedType;

  const NewMeetingScreen({super.key, this.preselectedType});

  @override
  State<NewMeetingScreen> createState() => _NewMeetingScreenState();
}

class _NewMeetingScreenState extends State<NewMeetingScreen> {
  final MeetingService _meetingService = MeetingService();
  final AdcomAgendaService _adcomAgendaService = AdcomAgendaService();
  final _formKey = GlobalKey<FormState>();

  String _meetingType = 'adcom';
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _virtualLinkController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);

  String? _chairpersonId;
  String? _chairpersonName;
  String? _secretaryId;
  String? _secretaryName;

  final List<MeetingMember> _invitedMembers = [];
  bool _isLoading = false;
  bool _useTemplate = false;

  List<Map<String, dynamic>> _availableUsers = [];

  @override
  void initState() {
    super.initState();
    if (widget.preselectedType != null) {
      _meetingType = widget.preselectedType!;
    }
    _loadUsers();
    _setDefaultTitle();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _virtualLinkController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _setDefaultTitle() {
    final monthYear = DateFormat('MMMM yyyy').format(_selectedDate);
    _titleController.text = _meetingType == 'board'
        ? 'HC Board Meeting - $monthYear'
        : 'HC ADCOM Meeting - $monthYear';
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
    } catch (e) {
      debugPrint('Error loading users: $e');
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _setDefaultTitle();
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

  void _showMemberPicker() {
    // Create a local copy to track selections in the dialog
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
                              // Update the parent state with selections
                              setState(() {
                                // Remove internal members and add the new selection
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

  Future<void> _createMeeting() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final meeting = Meeting(
        id: '',
        type: _meetingType,
        title: _titleController.text.trim(),
        dateTime: dateTime,
        location: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        virtualLink: _virtualLinkController.text.trim().isNotEmpty
            ? _virtualLinkController.text.trim()
            : null,
        status: 'scheduled',
        chairpersonId: _chairpersonId,
        chairpersonName: _chairpersonName,
        secretaryId: _secretaryId,
        secretaryName: _secretaryName,
        invitedMembers: _invitedMembers,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        createdBy: user?.id ?? '',
        createdAt: DateTime.now(),
      );

      final meetingId = await _meetingService.createMeeting(meeting);

      // Create agenda now if requested (ADCOM agenda format)
      if (_useTemplate) {
        final now = DateTime.now();
        final agenda = adcom.AdcomAgenda(
          id: '',
          organization: AppConstants.organizationName.toUpperCase(),
          meetingDate: dateTime,
          meetingTime: DateFormat('h:mm a').format(dateTime),
          location: meeting.location ?? '',
          attendanceMembers: const [],
          agendaItems: const [],
          status: 'draft',
          startingItemSequence: 1,
          createdAt: now,
          updatedAt: now,
          createdBy: user?.id ?? '',
        );
        final agendaId = await _adcomAgendaService.createAgenda(agenda);
        await _meetingService.updateMeeting(
          meeting.copyWith(id: meetingId, agendaId: agendaId, updatedAt: now),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meeting scheduled successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/meetings/$meetingId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating meeting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildWelcomeHeader(),
                ),
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMeetingTypeSelector(),
                        const SizedBox(height: 24),
                        _buildBasicInfoSection(),
                        const SizedBox(height: 24),
                        _buildDateTimeSection(),
                        const SizedBox(height: 24),
                        _buildLocationSection(),
                        const SizedBox(height: 24),
                        _buildRolesSection(),
                        const SizedBox(height: 24),
                        _buildMembersSection(),
                        const SizedBox(height: 24),
                        _buildOptionsSection(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.indigo.shade400, Colors.indigo.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.shade200,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildHeaderActionButton(
                    icon: Icons.close,
                    tooltip: 'Close',
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderActionButton(
                    icon: Icons.home_outlined,
                    tooltip: 'Home',
                    onPressed: () => context.go('/'),
                  ),
                ],
              ),
              if (!_isLoading)
                _buildHeaderActionButton(
                  icon: Icons.check,
                  tooltip: 'Create',
                  onPressed: _createMeeting,
                )
              else
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.event, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Schedule Meeting',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Create a new meeting event',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
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
            _setDefaultTitle();
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
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.notes),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeSection() {
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');

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
                flex: 2,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.calendar_today,
                      color: Colors.indigo,
                    ),
                  ),
                  title: const Text('Date'),
                  subtitle: Text(dateFormat.format(_selectedDate)),
                  onTap: _selectDate,
                ),
              ),
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.access_time, color: Colors.indigo),
                  ),
                  title: const Text('Time'),
                  subtitle: Text(_selectedTime.format(context)),
                  onTap: _selectTime,
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
              hintText: 'e.g., Conference Room A',
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
            items: _availableUsers.map((user) {
              return DropdownMenuItem<String>(
                value: user['id'] as String,
                child: Text(user['name'] as String),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _chairpersonId = value;
                _chairpersonName =
                    _availableUsers.firstWhere((u) => u['id'] == value)['name']
                        as String?;
              });
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
            items: _availableUsers.map((user) {
              return DropdownMenuItem<String>(
                value: user['id'] as String,
                child: Text(user['name'] as String),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _secretaryId = value;
                _secretaryName =
                    _availableUsers.firstWhere((u) => u['id'] == value)['name']
                        as String?;
              });
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

  Widget _buildOptionsSection() {
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
            'Options',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _useTemplate,
            onChanged: (value) {
              setState(() => _useTemplate = value);
            },
            title: const Text('Create agenda now (optional)'),
            subtitle: Text(
              'If off, you can create the agenda later from the meeting\'s Agenda tab',
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

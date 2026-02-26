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
import '../../utils/responsive_helper.dart';

class NewMeetingScreen extends StatefulWidget {
  final String? preselectedType;

  const NewMeetingScreen({super.key, this.preselectedType});

  @override
  State<NewMeetingScreen> createState() => _NewMeetingScreenState();
}

class _NewMeetingScreenState extends State<NewMeetingScreen> {
  static const String _externalMemberValue = '__external__';
  final MeetingService _meetingService = MeetingService();
  final AdcomAgendaService _adcomAgendaService = AdcomAgendaService();
  final _formKey = GlobalKey<FormState>();

  String _meetingType = 'adcom';
  MeetingMode _meetingMode = MeetingMode.faceToFace;
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

  static final List<MeetingMember> _defaultAdcomMembers = [
    MeetingMember(
      oderId: 'external_adcom_chair',
      name: 'Pr. Heary Healdy Sairin',
      role: 'Chair',
      organization: 'HC',
    ),
    MeetingMember(
      oderId: 'external_adcom_secretary',
      name: 'Pr. Kungwalpai Poodjing',
      role: 'Secretary',
      organization: 'HC',
    ),
    MeetingMember(
      oderId: 'external_adcom_treasurer',
      name: 'Archan Samorn Namkote',
      role: 'SEUM Treasurer',
      organization: 'SEUM',
    ),
    MeetingMember(
      oderId: 'external_adcom_member_bruno',
      name: 'Pr. Bruno Barbosa',
      role: 'HC Member',
      organization: 'HC',
    ),
    MeetingMember(
      oderId: 'external_adcom_member_doreen',
      name: 'Mrs. Doreen Neo',
      role: 'HC Member',
      organization: 'HC',
    ),
    MeetingMember(
      oderId: 'external_adcom_member_anniston',
      name: 'Mr. Anniston Mathews',
      role: 'HC Member',
      organization: 'HC',
    ),
  ];

  static final List<MeetingMember> _defaultBoardMembers = [
    MeetingMember(
      oderId: 'external_board_abel',
      name: 'Abel Bana',
      role: 'MAUM',
      organization: 'MAUM',
    ),
    MeetingMember(
      oderId: 'external_board_nipitpon',
      name: 'Nipitpon Pongteekatasana',
      role: 'SEUM CHAIR',
      organization: 'SEUM',
    ),
    MeetingMember(
      oderId: 'external_board_nelson',
      name: 'Nelson Bendah',
      role: 'MAUM',
      organization: 'MAUM',
    ),
    MeetingMember(
      oderId: 'external_board_lim',
      name: 'Lim Pheng',
      role: 'SEUM',
      organization: 'SEUM',
    ),
    MeetingMember(
      oderId: 'external_board_samorn',
      name: 'Samorn Namkote',
      role: 'SEUM',
      organization: 'SEUM',
    ),
    MeetingMember(
      oderId: 'external_board_joshua',
      name: 'Joshua Chee',
      role: 'MAUM',
      organization: 'MAUM',
    ),
    MeetingMember(
      oderId: 'external_board_chaiwat',
      name: 'Chaiwat Konratanasak',
      role: 'SEUM',
      organization: 'SEUM',
    ),
    MeetingMember(
      oderId: 'external_board_farrel',
      name: 'Farrel Gara',
      role: 'MAUM',
      organization: 'MAUM',
    ),
    MeetingMember(
      oderId: 'external_board_heary',
      name: 'Heary Healdy Sairin',
      role: 'HC Secretary',
      organization: 'HC',
    ),
  ];

  List<adcom.AttendanceMember> _buildAttendanceMembers() {
    return _invitedMembers.map((member) {
      return adcom.AttendanceMember(
        name: member.name,
        affiliation: member.organization ?? 'HC',
        isPresent: true,
        isAbsentWithApology: false,
      );
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    if (widget.preselectedType != null) {
      _meetingType = widget.preselectedType!;
    }
    _loadUsers();
    _setDefaultTitle();
    _ensureDefaultAdcomMembers();
    _ensureDefaultBoardMembers();
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

  void _ensureDefaultAdcomMembers() {
    if (_meetingType != 'adcom') return;
    if (_invitedMembers.isNotEmpty) return;
    _invitedMembers.addAll([
      MeetingMember(
        oderId: 'external_adcom_chair',
        name: 'Pr. Heary Healdy Sairin',
        role: 'Chair',
        organization: 'HC',
      ),
      MeetingMember(
        oderId: 'external_adcom_secretary',
        name: 'Pr. Kungwalpai Poodjing',
        role: 'Secretary',
        organization: 'HC',
      ),
      MeetingMember(
        oderId: 'external_adcom_treasurer',
        name: 'Archan Samorn Namkote',
        role: 'SEUM Treasurer',
        organization: 'SEUM',
      ),
      MeetingMember(
        oderId: 'external_adcom_member_bruno',
        name: 'Pr. Bruno Barbosa',
        role: 'HC Member',
        organization: 'HC',
      ),
      MeetingMember(
        oderId: 'external_adcom_member_doreen',
        name: 'Mrs. Doreen Neo',
        role: 'HC Member',
        organization: 'HC',
      ),
      MeetingMember(
        oderId: 'external_adcom_member_anniston',
        name: 'Mr. Anniston Mathews',
        role: 'HC Member',
        organization: 'HC',
      ),
    ]);
  }

  void _ensureDefaultBoardMembers() {
    if (_meetingType != 'board') return;
    final existing = _invitedMembers.map((m) => m.name.trim()).toSet();
    for (final member in _defaultBoardMembers) {
      if (!existing.contains(member.name.trim())) {
        _invitedMembers.add(member);
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
        meetingModeValue: _meetingMode.value,
        status: 'scheduled',
        chairpersonId: _chairpersonId == _externalMemberValue
            ? null
            : _chairpersonId,
        chairpersonName: _chairpersonName,
        secretaryId: _secretaryId == _externalMemberValue ? null : _secretaryId,
        secretaryName: _secretaryName,
        invitedMembers: _invitedMembers,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        createdBy: user?.id ?? '',
        createdAt: DateTime.now(),
      );

      final meetingId = await _meetingService.createMeeting(meeting);

      // Create agenda now if requested (ADCOM/Board agenda format)
      if (_useTemplate) {
        final now = DateTime.now();
        // Determine organization label for item number format
        final organizationLabel = _meetingType == 'adcom'
            ? 'ADCOM'
            : 'HC Board';
        final agenda = adcom.AdcomAgenda(
          id: '',
          organization: organizationLabel,
          meetingDate: dateTime,
          meetingTime: DateFormat('h:mm a').format(dateTime),
          location: meeting.location ?? '',
          attendanceMembers: _buildAttendanceMembers(),
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
            _ensureDefaultAdcomMembers();
            _ensureDefaultBoardMembers();
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
            'Meeting Mode & Location',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          // Meeting Mode Selector
          Row(
            children: [
              Expanded(
                child: _buildMeetingModeOption(
                  MeetingMode.faceToFace,
                  'Face to Face',
                  Icons.groups,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMeetingModeOption(
                  MeetingMode.virtual,
                  'Virtual',
                  Icons.videocam,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMeetingModeOption(
                  MeetingMode.evote,
                  'E-Vote',
                  Icons.how_to_vote,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Show location field only for face-to-face meetings
          if (_meetingMode == MeetingMode.faceToFace)
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Physical Location',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
                hintText: 'e.g., Conference Room A',
              ),
            ),
          // Show virtual link field for virtual meetings
          if (_meetingMode == MeetingMode.virtual)
            TextFormField(
              controller: _virtualLinkController,
              decoration: const InputDecoration(
                labelText: 'Virtual Meeting Link',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.videocam),
                hintText: 'e.g., Zoom or Teams link',
              ),
            ),
          // Show info for E-Vote
          if (_meetingMode == MeetingMode.evote)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'E-Vote meeting will be conducted via electronic voting system.',
                      style: TextStyle(color: Colors.orange.shade700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMeetingModeOption(
    MeetingMode mode,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = _meetingMode == mode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _meetingMode = mode;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRolesSection() {
    final defaultNames = _meetingType == 'adcom'
        ? _defaultAdcomMembers.map((m) => m.name).toSet()
        : _meetingType == 'board'
            ? _defaultBoardMembers.map((m) => m.name).toSet()
            : <String>{};
    final filteredMembers = defaultNames.isEmpty
        ? _invitedMembers
        : _invitedMembers
            .where((m) => defaultNames.contains(m.name))
            .toList();
    final memberOptions = filteredMembers.isEmpty
        ? _invitedMembers
        : filteredMembers
        .fold<Map<String, MeetingMember>>({}, (acc, member) {
          acc[member.oderId] = member;
          return acc;
        })
        .values
        .toList();
    final chairValue = memberOptions.any((m) => m.oderId == _chairpersonId)
        ? _chairpersonId
        : (_chairpersonId == _externalMemberValue ? _chairpersonId : null);
    final secretaryValue = memberOptions.any((m) => m.oderId == _secretaryId)
        ? _secretaryId
        : (_secretaryId == _externalMemberValue ? _secretaryId : null);

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
            value: chairValue,
            decoration: const InputDecoration(
              labelText: 'Chairperson',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            items: [
              ...memberOptions.map((member) {
                return DropdownMenuItem<String>(
                  value: member.oderId,
                  child: Text(member.name),
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
                  _chairpersonName = memberOptions
                      .firstWhere((m) => m.oderId == value)
                      .name;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: secretaryValue,
            decoration: const InputDecoration(
              labelText: 'Secretary / Minutes Taker',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.edit_note),
            ),
            items: [
              ...memberOptions.map((member) {
                return DropdownMenuItem<String>(
                  value: member.oderId,
                  child: Text(member.name),
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
                  _secretaryName = memberOptions
                      .firstWhere((m) => m.oderId == value)
                      .name;
                });
              }
            },
          ),
        ],
      ),
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

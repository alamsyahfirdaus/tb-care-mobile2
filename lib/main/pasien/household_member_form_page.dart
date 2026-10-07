import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:apk_tb_care/models/close_contact.dart';
import 'package:apk_tb_care/services/close_contact_service.dart';
import 'package:apk_tb_care/values/colors.dart';

class HouseholdMemberFormPage extends StatefulWidget {
  final CloseContact? existingContact;
  final int? patientId;

  const HouseholdMemberFormPage({
    super.key,
    this.existingContact,
    this.patientId,
  });

  bool get isEdit => existingContact != null;

  @override
  State<HouseholdMemberFormPage> createState() =>
      _HouseholdMemberFormPageState();
}

class _HouseholdMemberFormPageState extends State<HouseholdMemberFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nikController;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _notesController;

  String? _selectedGender; // 'L' atau 'P'
  DateTime? _selectedDateOfBirth;
  String? _selectedRelationship;
  bool _isSaving = false;

  // Daftar opsi hubungan keluarga yang umum dan mudah dipahami
  final List<String> _relationshipOptions = [
    'Anak',
    'Suami/Istri',
    'Ayah',
    'Ibu',
    'Saudara',
    'Kakek/Nenek',
    'Cucu',
    'Keluarga Serumah',
    'Pengasuh',
    'Teman Kerja',
    'Tetangga Dekat',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.existingContact;

    _nikController = TextEditingController(text: c?.nik ?? '');
    _nameController = TextEditingController(text: c?.name ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _notesController = TextEditingController(text: c?.notes ?? '');

    _selectedGender = c?.gender;
    _selectedRelationship = c?.relationship;
    if (_selectedRelationship != null &&
        !_relationshipOptions.contains(_selectedRelationship)) {
      _relationshipOptions.insert(0, _selectedRelationship!);
    }

    if (c?.dateOfBirth != null && c!.dateOfBirth!.isNotEmpty) {
      try {
        _selectedDateOfBirth = DateTime.parse(c.dateOfBirth!);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nikController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final initial = _selectedDateOfBirth ?? DateTime(now.year - 20, 1, 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'PILIH TANGGAL LAHIR',
      cancelText: 'BATAL',
      confirmText: 'PILIH',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: const Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateOfBirth = picked;
      });
    }
  }

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age < 0 ? 0 : age;
  }

  Future<void> _saveContact() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    final payload = <String, dynamic>{
      'nik': _nikController.text.trim(),
      'name': _nameController.text.trim(),
      'gender': _selectedGender ?? 'L',
      if (_selectedDateOfBirth != null)
        'date_of_birth':
            DateFormat('yyyy-MM-dd').format(_selectedDateOfBirth!),
      'age': _selectedDateOfBirth != null
          ? _calculateAge(_selectedDateOfBirth!)
          : (widget.existingContact?.age ?? 0),
      if (_phoneController.text.trim().isNotEmpty)
        'phone': _phoneController.text.trim(),
      'relationship': _selectedRelationship ?? 'Keluarga Serumah',
      if (_notesController.text.trim().isNotEmpty)
        'notes': _notesController.text.trim(),
      if (widget.existingContact?.address != null)
        'address': widget.existingContact!.address,
      if (widget.patientId != null) 'patient_id': widget.patientId,
    };

    try {
      if (widget.isEdit) {
        await CloseContactService.updateContact(
            widget.existingContact!.id, payload);
      } else {
        await CloseContactService.createContact(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEdit
                  ? 'Data anggota berhasil diperbarui.'
                  : 'Anggota serumah berhasil ditambahkan.',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal menyimpan: $e',
              style: GoogleFonts.plusJakartaSans(),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.isEdit ? 'Ubah Anggota Serumah' : 'Tambah Anggota Serumah',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFormCard(),
              const SizedBox(height: 24),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. NIK *
          _buildFieldLabel('NIK', isRequired: true),
          TextFormField(
            controller: _nikController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(16),
            ],
            style: GoogleFonts.plusJakartaSans(fontSize: 14),
            decoration: _inputDecoration(
              hintText: '16 digit NIK',
              prefixIcon: Icons.badge_outlined,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'NIK wajib diisi.';
              }
              if (val.trim().length != 16) {
                return 'NIK harus 16 digit.';
              }
              if (!RegExp(r'^[0-9]+$').hasMatch(val.trim())) {
                return 'NIK hanya boleh berisi angka.';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          // 2. Nama Lengkap *
          _buildFieldLabel('Nama Lengkap', isRequired: true),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            style: GoogleFonts.plusJakartaSans(fontSize: 14),
            decoration: _inputDecoration(
              hintText: 'Nama Lengkap sesuai KTP',
              prefixIcon: Icons.person_outline_rounded,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Nama lengkap wajib diisi.';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          // 3. Jenis Kelamin *
          _buildFieldLabel('Jenis Kelamin', isRequired: true),
          DropdownButtonFormField<String>(
            initialValue: _selectedGender,
            decoration: _inputDecoration(
              hintText: 'Pilih jenis kelamin',
              prefixIcon: Icons.wc_outlined,
            ),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: const Color(0xFF0F172A),
            ),
            dropdownColor: Colors.white,
            items: const [
              DropdownMenuItem<String>(
                value: 'L',
                child: Text('Laki-laki'),
              ),
              DropdownMenuItem<String>(
                value: 'P',
                child: Text('Perempuan'),
              ),
            ],
            onChanged: (val) {
              setState(() => _selectedGender = val);
            },
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Jenis kelamin wajib dipilih.';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          // 4. Tanggal Lahir (Opsional)
          _buildFieldLabel('Tanggal Lahir', isRequired: false),
          InkWell(
            onTap: _pickDateOfBirth,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFF8FAFC),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    size: 20,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedDateOfBirth != null
                          ? DateFormat('d MMMM y', 'id_ID')
                              .format(_selectedDateOfBirth!)
                          : 'Pilih Tanggal',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: _selectedDateOfBirth != null
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF94A3B8),
                        fontWeight: _selectedDateOfBirth != null
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (_selectedDateOfBirth != null)
                    GestureDetector(
                      onTap: () => setState(() => _selectedDateOfBirth = null),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 5. Nomor Handphone / WhatsApp (Opsional)
          _buildFieldLabel('Nomor Handphone / WhatsApp', isRequired: false),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.plusJakartaSans(fontSize: 14),
            decoration: _inputDecoration(
              hintText: 'Contoh: 0812xxxxxxxx',
              prefixIcon: Icons.phone_outlined,
            ),
          ),
          const SizedBox(height: 18),

          // 6. Hubungan dengan Pasien (Opsional)
          _buildFieldLabel('Hubungan dengan Pasien', isRequired: false),
          DropdownButtonFormField<String>(
            initialValue: _selectedRelationship,
            decoration: _inputDecoration(
              hintText: 'Pilih hubungan keluarga',
              prefixIcon: Icons.family_restroom_rounded,
            ),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: const Color(0xFF0F172A),
            ),
            dropdownColor: Colors.white,
            items: _relationshipOptions.map((rel) {
              return DropdownMenuItem<String>(
                value: rel,
                child: Text(rel),
              );
            }).toList(),
            onChanged: (val) {
              setState(() => _selectedRelationship = val);
            },
          ),
          const SizedBox(height: 18),

          // 7. Catatan Tambahan (Opsional)
          _buildFieldLabel('Catatan Tambahan', isRequired: false),
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            style: GoogleFonts.plusJakartaSans(fontSize: 14),
            decoration: _inputDecoration(
              hintText:
                  'Contoh: Memiliki riwayat batuk atau informasi lainnya...',
              prefixIcon: Icons.notes_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label, {required bool isRequired}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
          if (isRequired)
            const Text(
              ' *',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.plusJakartaSans(
        color: const Color(0xFF94A3B8),
        fontSize: 13,
      ),
      prefixIcon: Icon(prefixIcon, size: 20, color: const Color(0xFF64748B)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isSaving ? null : _saveContact,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 1,
      ),
      child: _isSaving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text(
              widget.isEdit ? 'Simpan Perubahan' : 'Simpan Anggota',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
    );
  }
}

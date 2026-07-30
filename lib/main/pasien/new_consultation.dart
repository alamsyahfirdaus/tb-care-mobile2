import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'consultation_service.dart';

class NewConsultationPage extends StatefulWidget {
  final ConsultationService service;
  final String currentUserId;
  final String currentUserName;

  const NewConsultationPage({
    super.key,
    required this.service,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<NewConsultationPage> createState() => _NewConsultationPageState();
}

class _NewConsultationPageState extends State<NewConsultationPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  File? _attachment;
  String? _attachmentName;
  bool _isPublic = true;
  String? _selectedRecipientId;
  bool _isSubmitting = false;
  bool _isLoadingRecipients = false;
  List<Map<String, dynamic>> _recipients = [];

  @override
  void initState() {
    super.initState();
    _loadRecipientsIfNeeded();
  }

  Future<void> _loadRecipientsIfNeeded() async {
    if (_recipients.isEmpty) {
      setState(() => _isLoadingRecipients = true);
      try {
        final recipients = await widget.service.loadRecipients();
        setState(() {
          _recipients = recipients;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal memuat daftar petugas: ${e.toString()}'),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoadingRecipients = false);
        }
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
        ],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileSize = await file.length();

        // Limit file size to 5MB
        if (fileSize > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ukuran file maksimal 5MB')),
            );
          }
          return;
        }

        setState(() {
          _attachment = file;
          _attachmentName = result.files.single.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih file: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _submitConsultation() async {
    if (!_formKey.currentState!.validate()) return;
    if (_messageController.text.trim().isEmpty && _attachment == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pesan atau lampiran harus diisi')),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.service.createConsultation(
        title: _titleController.text,
        message: _messageController.text,
        senderId: widget.currentUserId,
        senderName: widget.currentUserName,
        recipientId: _isPublic ? null : _selectedRecipientId,
        attachment: _attachment,
        attachmentName: _attachmentName,
      );

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konsultasi berhasil dikirim')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat konsultasi: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Konsultasi Baru'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () async {
              await showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Informasi'),
                      content: const Text(
                        'Konsultasi publik dapat dilihat oleh semua petugas. '
                        'Pilih petugas tertentu untuk konsultasi privat.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Mengerti'),
                        ),
                      ],
                    ),
              );
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Judul*',
                  hintText: 'Masukkan judul konsultasi',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Judul harus diisi';
                  }
                  if (value.length > 100) {
                    return 'Judul maksimal 100 karakter';
                  }
                  return null;
                },
                maxLength: 100,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Pesan',
                  hintText: 'Tulis pertanyaan atau keluhan Anda',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                minLines: 3,
                maxLength: 1000,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tipe Konsultasi',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Radio<bool>(
                            value: true,
                            // ignore: deprecated_member_use
                            groupValue: _isPublic,
                            // ignore: deprecated_member_use
                            onChanged: (value) {
                              setState(() {
                                _isPublic = value ?? true;
                                _selectedRecipientId = null;
                              });
                            },
                          ),
                          const Text('Publik'),
                          const SizedBox(width: 16),
                          Radio<bool>(
                            value: false,
                            // ignore: deprecated_member_use
                            groupValue: _isPublic,
                            // ignore: deprecated_member_use
                            onChanged: (value) {
                              setState(() => _isPublic = value ?? false);
                            },
                          ),
                          const Text('Privat'),
                        ],
                      ),
                      if (!_isPublic) ...[
                        const SizedBox(height: 8),
                        _isLoadingRecipients
                            ? const LinearProgressIndicator()
                            : DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Pilih Petugas Kesehatan*',
                                border: OutlineInputBorder(),
                              ),
                              // ignore: deprecated_member_use
                              value: _selectedRecipientId,
                              items:
                                  _recipients.map((recipient) {
                                    return DropdownMenuItem<String>(
                                      value: recipient['id'].toString(),
                                      child: Text(recipient['name']),
                                    );
                                  }).toList(),
                              onChanged: (value) {
                                setState(() => _selectedRecipientId = value);
                              },
                              validator: (value) {
                                if (!_isPublic &&
                                    (value == null || value.isEmpty)) {
                                  return 'Harap pilih petugas';
                                }
                                return null;
                              },
                            ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_attachment != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.attach_file),
                    title: Text(
                      _attachmentName ?? 'Lampiran',
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${(_attachment!.lengthSync() / 1024).toStringAsFixed(1)} KB',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _attachment = null;
                          _attachmentName = null;
                        });
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.attach_file),
                label: const Text('Lampirkan File'),
                onPressed: _pickFile,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Format: JPG, PNG, PDF, DOC, XLS (Maks. 5MB)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitConsultation,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child:
                      _isSubmitting
                          ? const CircularProgressIndicator()
                          : const Text(
                            'Kirim Konsultasi',
                            style: TextStyle(fontSize: 16),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

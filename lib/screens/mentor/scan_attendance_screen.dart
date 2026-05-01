import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_utils.dart';
import '../../models/attendance_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

/// Mentor screen that opens the device camera, scans the intern's
/// Pro-Link Work-ID QR code and instantly marks attendance for today.
///
/// QR payload (created by `WorkIdCardScreen`):
/// ```json
/// {"type": "prolink-id", "internId": "...", "studentId": "...", "name": "..."}
/// ```
class ScanAttendanceScreen extends StatefulWidget {
  const ScanAttendanceScreen({super.key});

  @override
  State<ScanAttendanceScreen> createState() => _ScanAttendanceScreenState();
}

class _ScanAttendanceScreenState extends State<ScanAttendanceScreen> {
  final MobileScannerController _controller =
      MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _processing = false;
  String? _lastResult;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    setState(() => _processing = true);

    try {
      final payload = jsonDecode(raw);
      if (payload is! Map ||
          payload['type'] != 'prolink-id' ||
          payload['internId'] is! String) {
        throw const FormatException('Not a Pro-Link QR code');
      }
      final internId = payload['internId'] as String;
      final internName = payload['name'] as String? ?? 'Intern';

      final mentorId =
          context.read<AuthService>().currentUser?.id ?? 'unknown';
      final today = DateTime.now();
      final attendance = AttendanceModel(
        id: '',
        internId: internId,
        mentorId: mentorId,
        date: DateTime(today.year, today.month, today.day),
        status: AppConstants.attendancePresent,
        note: 'Marked via QR scan',
      );
      await context.read<FirestoreService>().createAttendance(attendance);

      if (!mounted) return;
      setState(() => _lastResult = internName);
      AppUtils.showSnackBar(
        context,
        '$internName marked present for ${AppUtils.formatDate(today)}',
      );
    } catch (e) {
      if (!mounted) return;
      AppUtils.showSnackBar(
        context,
        'Invalid QR code or save failed: $e',
        isError: true,
      );
    } finally {
      // Cooldown so a single scan doesn't fire dozens of detections.
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Scan Attendance'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
                // A simple overlay frame to guide the user.
                Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.accent,
                        width: 3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            color: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aim the camera at the intern\'s Work-ID QR code.',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  _lastResult == null
                      ? 'No scans yet.'
                      : 'Last scan: $_lastResult marked present.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

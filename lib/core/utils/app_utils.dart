import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';

class AppUtils {
  AppUtils._();

  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  static String formatDateLong(DateTime date) {
    return DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(date);
  }

  static Color getStatusColor(String status) {
    switch (status) {
      case AppConstants.statusActive:
        return AppColors.success;
      case AppConstants.statusPending:
        return AppColors.warning;
      case AppConstants.statusRejected:
        return AppColors.error;
      case AppConstants.statusCompleted:
        return AppColors.accent;
      default:
        return AppColors.textSecondary;
    }
  }

  static String getStatusLabel(String status) {
    switch (status) {
      case AppConstants.statusActive:
        return 'Actif';
      case AppConstants.statusPending:
        return 'En attente';
      case AppConstants.statusRejected:
        return 'Rejeté';
      case AppConstants.statusCompleted:
        return 'Terminé';
      default:
        return status;
    }
  }

  static Color getAttendanceColor(String status) {
    switch (status) {
      case AppConstants.attendancePresent:
        return AppColors.success;
      case AppConstants.attendanceAbsent:
        return AppColors.error;
      case AppConstants.attendanceLate:
        return AppColors.warning;
      case AppConstants.attendanceJustified:
        return AppColors.accent;
      default:
        return AppColors.textSecondary;
    }
  }

  static String getAttendanceLabel(String status) {
    switch (status) {
      case AppConstants.attendancePresent:
        return 'Présent';
      case AppConstants.attendanceAbsent:
        return 'Absent';
      case AppConstants.attendanceLate:
        return 'En retard';
      case AppConstants.attendanceJustified:
        return 'Justifié';
      default:
        return status;
    }
  }

  static IconData getFileTypeIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'video':
      case 'mp4':
      case 'avi':
        return Icons.video_library;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      default:
        return Icons.insert_drive_file;
    }
  }

  static String getRoleLabel(String role) {
    switch (role) {
      case AppConstants.roleAdmin:
        return 'Administrateur';
      case AppConstants.roleMentor:
        return 'Encadreur';
      case AppConstants.roleIntern:
        return 'Stagiaire';
      default:
        return role;
    }
  }

  static Color getRoleColor(String role) {
    switch (role) {
      case AppConstants.roleAdmin:
        return AppColors.gold;
      case AppConstants.roleMentor:
        return AppColors.accent;
      case AppConstants.roleIntern:
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  static void showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  static Future<bool?> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = 'Confirmer',
    String cancelText = 'Annuler',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  static String getWeekLabel(DateTime date) {
    final weekNumber = weekOfYear(date);
    final month = DateFormat('MMMM yyyy', 'fr_FR').format(date);
    return 'Semaine $weekNumber – $month';
  }

  static int weekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final diff = date.difference(firstDayOfYear);
    return ((diff.inDays + firstDayOfYear.weekday - 1) / 7).ceil();
  }
}

class AppConstants {
  AppConstants._();

  static const String appName = 'Pro-Link';
  static const String appVersion = '1.0.0';

  // Collections
  static const String usersCollection = 'users';
  static const String internsCollection = 'interns';
  static const String departmentsCollection = 'departments';
  static const String mentorsCollection = 'mentors';
  static const String evaluationsCollection = 'evaluations';
  static const String attendanceCollection = 'attendance';
  static const String schedulesCollection = 'schedules';
  static const String trainingFilesCollection = 'training_files';
  static const String notificationsCollection = 'notifications';

  // Storage paths
  static const String profilePhotosPath = 'profile_photos';
  static const String trainingFilesPath = 'training_files';
  static const String schedulesPath = 'schedules';
  static const String policiesPath = 'policies';

  // User roles
  static const String roleAdmin = 'admin';
  static const String roleMentor = 'mentor';
  static const String roleIntern = 'intern';

  // Intern status
  static const String statusPending = 'pending';
  static const String statusActive = 'active';
  static const String statusRejected = 'rejected';
  static const String statusCompleted = 'completed';

  // Shared prefs keys
  static const String prefUserRole = 'user_role';
  static const String prefUserId = 'user_id';
  static const String prefUserEmail = 'user_email';

  // Universities
  static const List<String> universities = [
    'Constantine 2 University – Abdelhamid Mehri',
    'Constantine 1 University – Mentouri Brothers',
    'Constantine 3 University',
    'Other',
  ];

  // Departments
  static const List<String> departments = [
    'Computer Science',
    'Software Engineering',
    'Networks and Telecommunications',
    'Artificial Intelligence',
    'Embedded Systems',
    'Cybersecurity',
    'Data Science',
    'Other',
  ];

  // Evaluation criteria
  static const List<String> evaluationCriteria = [
    'Technical Skills',
    'Communication',
    'Punctuality',
    'Initiative',
    'Teamwork',
    'Adaptability',
  ];

  // Attendance statuses
  static const String attendancePresent = 'present';
  static const String attendanceAbsent = 'absent';
  static const String attendanceLate = 'late';
  static const String attendanceJustified = 'justified';
}

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
    'Université Constantine 2 – Abdelhamid Mehri',
    'Université Constantine 1 – Frères Mentouri',
    'Université Constantine 3',
    'Autre',
  ];

  // Departments
  static const List<String> departments = [
    'Informatique',
    'Génie Logiciel',
    'Réseaux et Télécommunications',
    'Intelligence Artificielle',
    'Systèmes Embarqués',
    'Cybersécurité',
    'Data Science',
    'Autre',
  ];

  // Evaluation criteria
  static const List<String> evaluationCriteria = [
    'Compétences Techniques',
    'Communication',
    'Ponctualité',
    'Initiative',
    'Travail en Équipe',
    'Adaptabilité',
  ];

  // Attendance statuses
  static const String attendancePresent = 'present';
  static const String attendanceAbsent = 'absent';
  static const String attendanceLate = 'late';
  static const String attendanceJustified = 'justified';
}

class CampusData {
  // Structure: College -> School -> Department -> Course
  static final Map<String, Map<String, Map<String, List<String>>>> hierarchy = {
    // 1. College of Agriculture & Natural Resources (COANRE)
    'COANRE': {
      'School of Agriculture & Env. Sciences': {
        'Landscape & Environmental Sciences': [
          'BSc. Environmental Horticulture and Landscaping Technology',
          'BSc. Environmental Horticulture'
        ],
        'Horticulture & Food Security': [
          'BSc. Horticulture',
          'MSc. Plant Breeding',
          'MSc. Horticulture',
          'MSc. Plant Health Science & Management'
        ],
        'Agricultural Resource Economics': [
          'BSc. Agriculture',
          'Agricultural and Resource Economics'
        ]
      },
      'School of Natural Resources & Animal Sciences': {
        'Animal Sciences': [
          'BSc. Animal Health Production & Processing',
          'MSc. Animal Nutrition'
        ],
        'Land Resource Planning': [
          'BSc. Land Resource Planning and Management'
        ]
      },
      'School of Food & Nutrition Sciences': {
        'Human Nutrition Sciences': [
          'BSc. Human Nutrition and Dietetics',
          'BSc. Food Service and Hospitality Management',
          'BSc. Nutraceutical Sciences',
          'MSc. Food Science and Nutrition'
        ],
        'Food Science & Technology': [
          'BSc. Food Science and Technology'
        ]
      }
    },

    // 2. College of Engineering & Technology (COETEC)
    'COETEC': {
      'School of Architecture & Building Sciences': {
        'Landscape Architecture': [
          'Bachelor of Landscape Architecture',
          'Master of Landscape Architecture'
        ],
        'Architecture': [
          'Bachelor of Architecture',
          'Bachelor of Architectural Studies',
          'Master of Urban Design'
        ],
        'Construction Management': [
          'Bachelor of Construction Management',
          'Bachelor of Quantity Surveying',
          'Bachelor of Real Estate',
          'MSc. Construction Project Management'
        ]
      },
      'School of Biosystems & Environmental Eng.': {
        'Ag. & Biosystems Engineering': [
          'BSc. Agricultural and Biosystems Engineering',
          'BSc. Energy and Environmental Technology',
          'MSc. Agricultural and Processing Engineering'
        ],
        'Soil, Water & Env. Engineering': [
          'BSc. Water and Environment Management',
          'BSc. Water and Environmental Engineering',
          'MSc. Soil and Water Engineering'
        ]
      },
      'School of Civil, Env. & Geospatial Eng.': {
        'Geomatic Engineering & GIS': [
          'BSc. GIS',
          'BSc. GEGIS',
          'MSc. GIS and RS'
        ],
        'Civil Construction & Env. Eng': [
          'BSc. Civil Engineering'
        ]
      },
      'School of Mining & Petroleum Eng.': {
        'Petroleum Engineering': ['MSc. Petroleum Engineering'],
        'Mining Engineering': ['MSc. Mining Engineering']
      }
    },

    // 3. College of Health Sciences (COHES)
    'COHES': {
      'School of Medicine': {
        'Medicine & Surgery': ['MBChB (Bachelor of Medicine and Bachelor of Surgery)'],
        'Child Health & Paediatrics': ['Master of Medicine in Paediatrics'],
        'Physiotherapy': ['BSc. Physiotherapy'],
        'Clinical Medicine': [
          'BSc. Clinical Medicine',
          'BSc. Comprehensive Ophthalmology and Cataract Surgery'
        ]
      },
      'School of Biomedical Sciences': {
        'Biochemistry': [
          'BSc. Biochemistry & Molecular Biology',
          'BSc. Medical Biochemistry',
          'BSc. Industrial Biotechnology',
          'BSc. Applied Bioengineering'
        ],
        'Medical Microbiology': [
          'BSc. Medical Microbiology',
          'MSc. Infectious Diseases and Vaccinology'
        ],
        'Medical Laboratory Sciences': [
          'BSc. Medical Laboratory Science',
          'BSc. Radiography'
        ]
      },
      'School of Nursing': {
        'Nursing Dept': ['BSc. Nursing', 'MSc. Nursing']
      },
      'School of Public Health': {
        'Public Health': ['MSc. Public Health and Biostatistics', 'MSc. Global Health']
      }
    },

    // 4. College of Human Resource & Development (COHRED)
    'COHRED': {
      'School of Business': {
        'Business Administration': [
          'Bachelor of Commerce',
          'Diploma in Business Administration',
          'Certificate in Business Administration'
        ],
        'Business Information Technology': [
          'Bachelor of Business Information Technology (BBIT)',
          'Diploma in Business Information Technology'
        ],
        'Economics, Accounting & Finance': [
          'BSc. Economics',
          'BSc. Banking and Finance'
        ]
      },
      'School of Entrepreneurship & Procurement': {
        'Entrepreneurship': ['BSc. Entrepreneurship', 'MSc. Entrepreneurship'],
        'Procurement & Logistics': ['BSc. Procurement and Contract Management']
      },
      'School of Communication & Dev. Studies': {
        'Development Studies': [
          'Bachelor of Development Studies',
          'Bachelor of Public Management & Development',
          'Bachelor of Community Development & Environment'
        ],
        'Media Tech & Applied Comm.': [
          'Bachelor of Mass Communication',
          'Bachelor of Corporate Communication & Management',
          'Bachelor of Journalism'
        ]
      }
    },

    // 5. College of Pure & Applied Sciences (COPAS)
    'COPAS': {
      'School of Computing & IT': {
        'Information Technology': [
          'BSc. Information Technology (BIT)',
          'Diploma in IT (DIT)',
          'Certificate in IT'
        ],
        'Computing': [
          'BSc. Computer Science',
          'BSc. Computer Technology',
          'BSc. Data Science',
          'MSc. Software Engineering',
          'MSc. Artificial Intelligence'
        ]
      },
      'School of Physical Sciences': {
        'Physics': [
          'BSc. Physics',
          'BSc. Control and Instrumentation',
          'BSc. Geophysics',
          'BSc. Renewable Energy & Environmental Physics'
        ],
        'Chemistry': [
          'BSc. Chemistry',
          'BSc. Industrial Chemistry',
          'BSc. Analytical Chemistry'
        ]
      },
      'School of Mathematical Sciences': {
        'Mathematics': ['BSc. Mathematics', 'BSc. Actuarial Science']
      },
      'School of Biological Sciences': {
        'Botany': ['BSc. Botany', 'BSc. Microbiology'],
        'Zoology': ['BSc. Zoology', 'BSc. Genomic Sciences'],
        'Fisheries': ['BSc. Fisheries Science']
      }
    },
    'SCHOOL OF LAW': {
      'Law': {
        'Law': ['Bachelor of Laws (LL.B)']
      }
    }
  };

  // --- GETTERS ---

  static List<String> getColleges() => hierarchy.keys.toList();

  static List<String> getSchools(String college) =>
      hierarchy[college]?.keys.toList() ?? [];

  static List<String> getDepartments(String college, String school) =>
      hierarchy[college]?[school]?.keys.toList() ?? [];

  static List<String> getCourses(String college, String school, String dept) =>
      hierarchy[college]?[school]?[dept] ?? [];

  // --- LOGIC FOR GENERATING UNITS ---

  static List<String> getUnits(String course, String year, String semester) {
    List<String> units = [];
    String upperCourse = course.toUpperCase();

    // 1. Common Units (Applies to almost all first years/semesters)
    if (year == '1') {
      units.add('HRD 2101: Communication Skills');
      units.add('SZL 2111: HIV/AIDS');
      units.add('HBC 2102: Introduction to Business');
      units.add('TDH 1100: HIV/AIDS (Common)');
    }

    // 2. Specific Logic based on Course Name from your text dump

    if (upperCourse.contains('BUSINESS INFORMATION') || upperCourse.contains('BBIT')) {
      // BBIT Specifics from text
      units.addAll([
        'ICS 2101: Computer Organization',
        'HBT 2101: Fundamentals of Computer Systems',
        'HBT 2102: Computer Operating System',
        'HBT 2103: Financial Accounting',
        'HBC 2103: Mathematics for Business',
        'ICS 2${year}06: Internet Application Programming',
      ]);
    } else if (upperCourse.contains('COMMERCE') || upperCourse.contains('BUSINESS ADMIN')) {
      // BCOM Specifics from text
      units.addAll([
        'HBC 2106: Fundamentals of Computer Systems',
        'HCB 0101: Introduction to Micro-Economics',
        'HCB 0102: Introduction to Accounting I',
        'HCB 0104: Principles of Management'
      ]);
    } else if (upperCourse.contains('COMPUTER SCIENCE') || upperCourse.contains('COMPUTER TECHNOLOGY')) {
      // CS/CT Specifics
      units.addAll([
        'ICS 2${year}01: Programming Methodologies',
        'ICS 2${year}03: Distributed Systems',
        'ICS 2${year}05: Database Systems',
        'SMA 2104: Mathematics for Science',
        'ICS 220${semester}: Artificial Intelligence Fundamentals'
      ]);
    } else if (upperCourse.contains('HORTICULTURE') || upperCourse.contains('AGRICULTURE')) {
      // Agriculture Specifics
      units.addAll([
        'AHS 2${year}01: Plant Physiology',
        'AHS 2${year}02: Principles of Genetics',
        'SBC 2${year}01: Intro to Botany',
        'AHS 2${year}05: Soil Science'
      ]);
    } else if (upperCourse.contains('ENGINEERING')) {
      // Engineering General
      units.addAll([
        'SMA 2${year}70: Engineering Mathematics ${romanNumeral(semester)}',
        'FME 2${year}01: Workshop Practice',
        'EEE 2${year}02: Circuit Theory',
        'FCE 2${year}04: Engineering Mechanics'
      ]);
    } else {
      // 3. Fallback Dynamic Generation for other courses
      // Tries to create a code based on the course name (e.g., MEDICINE -> MED)
      final prefix = course.length > 4
          ? course.replaceAll('Bachelor of ', '').substring(0, 3).toUpperCase()
          : 'GEN';

      units.addAll([
        '$prefix 2${year}01: Introduction to ${course.replaceAll('Bachelor of ', '')}',
        '$prefix 2${year}02: Advanced Concepts in ${semester == '1' ? 'Theory' : 'Practice'}',
        '$prefix 2${year}03: Research Methods',
        '$prefix 2${year}04: Field Attachment / Practical',
        'HRA 2401: Entrepreneurship Skills',
      ]);
    }

    return units;
  }

  // Helper for Engineering Math Roman Numerals
  static String romanNumeral(String num) {
    if (num == '1') return 'I';
    if (num == '2') return 'II';
    return 'III';
  }
}
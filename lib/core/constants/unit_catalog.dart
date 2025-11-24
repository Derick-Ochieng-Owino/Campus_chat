// lib/core/constants/unit_catalog.dart
class UnitCatalog {
  /// Master unit catalog: unitCode -> human-readable name
  /// This list is substantial but not every single JKUAT unit; extend as needed.
  static final Map<String, String> units = {
    // COMMON / UNIVERSITY CORE
    'HRD2101': 'Communication Skills',
    'SZL2111': 'HIV/AIDS',
    'HBC2102': 'Introduction to Business',
    'TDH1100': 'HIV/AIDS (Common)',
    'ENT2401': 'Entrepreneurship Skills',
    'PROJ4001': 'Systems Project / Capstone',
    'COMM1101': 'Communication & Information Literacy',

    // BBIT / IT / COMPUTING CORE
    'ICS2101': 'Computer Organization',
    'PSI2101': 'Programming Methodologies',
    'ICS2201': 'Advanced Programming',
    'SWE2101': 'Software Engineering I',
    'DBS2101': 'Database Systems',
    'ICS2106': 'Internet Application Programming',
    'HBT2101': 'Fundamentals of Computer Systems',
    'HBT2102': 'Computer Operating Systems',
    'HBT2103': 'Financial Accounting',
    'HBC2103': 'Mathematics for Business',
    'AI3101' : 'Artificial Intelligence',
    'CSS2101': 'Computer Systems Security',
    'SMA2104': 'Mathematics for Science',

    // ENGINEERING / APPLIED
    'FME2001': 'Workshop Practice',
    'EEE2002': 'Circuit Theory',
    'FCE2004': 'Engineering Mechanics',
    'SMA2700': 'Engineering Mathematics I',

    // AGRICULTURE / HORTICULTURE / AHS
    'AHS2001': 'Plant Physiology',
    'AHS2002': 'Principles of Genetics',
    'SBC2001': 'Introductory Botany',
    'AHS2005': 'Soil Science',

    // BUSINESS / ECON / ACCOUNTING
    'HCB0101': 'Introduction to Microeconomics',
    'HCB0102': 'Introduction to Accounting I',
    'HCB0104': 'Principles of Management',
    'HBC2106': 'Fundamentals of Computer Systems (Business)',

    // BIO / HEALTH SCIENCES sample
    'BIO2101': 'Biochemistry I',
    'MIC2101': 'Microbiology I',
    'ANAT2101': 'Human Anatomy I',
    'PHYS2101': 'Physiology I',

    // LAW / COMMON
    'LAW2101': 'Introduction to Law',

    // more units (extend as you confirm)
    'NET3101': 'Computer Networks I',
    'WEB3101': 'Web Technologies',
    'OS3101': 'Operating Systems II',
    'ALG3201': 'Algorithms & Data Structures',
    'STAT2101': 'Statistics for Science',
  };
}

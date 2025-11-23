// lib/core/constants/unit_catalog.dart
class UnitCatalog {
  /// Master unit catalog: unitCode -> full human readable name
  /// Start here and expand as you confirm official codes/names.
  static final Map<String, String> units = {
    // Common / Generic
    'HRD2101': 'Communication Skills',
    'SZL2111': 'HIV/AIDS',
    'HBC2102': 'Introduction to Business',
    'TDH1100': 'HIV/AIDS (Common)',

    // BBIT / BIT / IT / Computing sample units (from JKUAT course lists)
    'ICS2101': 'Computer Organization',
    'HBT2101': 'Fundamentals of Computer Systems',
    'HBT2102': 'Computer Operating Systems',
    'HBT2103': 'Financial Accounting',
    'HBC2103': 'Mathematics for Business',
    'ICS2106': 'Internet Application Programming',
    'DBS2101': 'Database Systems',
    'SWE2101': 'Software Engineering I',
    'AI3101': 'Artificial Intelligence',
    'CSS2101': 'Computer Systems Security',
    'PSI2101': 'Programming Methodologies',
    'ICS2201': 'Programming II / Advanced Programming',
    'SMA2104': 'Mathematics for Science',

    // Engineering / AHS examples
    'FME2001': 'Workshop Practice',
    'EEE2002': 'Circuit Theory',
    'FCE2004': 'Engineering Mechanics',
    'SMA2700': 'Engineering Mathematics',

    // Agriculture / Horticulture examples
    'AHS201': 'Plant Physiology',
    'AHS202': 'Principles of Genetics',
    'SBC2001': 'Introductory Botany',

    // Useful core units
    'ENT2401': 'Entrepreneurship Skills',
    'PROJ4001': 'Systems Project / Capstone',
    'COMM1101': 'Communication & Information Literacy',

    // Add more real unit codes/names as you confirm them
  };
}

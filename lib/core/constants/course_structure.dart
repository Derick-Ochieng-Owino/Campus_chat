// lib/core/constants/course_structure.dart
import 'unit_catalog.dart';

class CourseStructure {
  /// Map of courseKey -> year -> semester -> list of unitCodes
  /// courseKey values: 'BBIT', 'COMPUTER_SCIENCE', 'BIT', 'BSC_CS', etc.
  static final Map<String, Map<String, Map<String, List<String>>>> curriculum = {
    // BBIT (Bachelor of Business Information Technology) — example based on SODeL lists.
    'BBIT': {
      '1': {
        '1': [
          'HRD2101',
          'SZL2111',
          'COMM1101',
          'ICS2101',     // Computer Organization
          'PSI2101',     // Programming Methodologies
          'HBC2102',
          'HBC2103',
        ],
        '2': [
          'DBS2101',    // Database Systems
          'SWE2101',    // Software Engineering I
          'HBT2102',    // Computer Operating Systems
          'ICS2106',    // Internet Application Programming
          'ENT2401',
        ],
      },
      '2': {
        '1': [
          'ICS2201',
          'CSS2101',
          'AI3101',
          'PROJ4001', // placeholder for project later
        ],
        '2': [
          'SMA2104',
          'AI3101',
        ],
      },
    },

    // Computer Science (BSc. Computer Science)
    'COMPUTER_SCIENCE': {
      '1': {
        '1': [
          'PSI2101', // Programming Methodologies
          'SMA2104', // Mathematics for Science
          'COMM1101',
          'ICS2101',
        ],
        '2': [
          'DBS2101',
          'SWE2101',
          'ICS2201',
        ],
      },
      '2': {
        '1': [
          'AI3101',
          'CSS2101',
        ],
        '2': [
          'PROJ4001',
        ],
      }
    },

    // Generic fallback example for BIT / IT
    'BIT': {
      '1': {
        '1': ['COMM1101', 'PSI2101', 'ICS2101'],
        '2': ['DBS2101', 'SWE2101'],
      },
    },

    // Add more course mappings here as you confirm official unit codes
  };

  /// Returns list of unit codes for course/year/semester
  static List<String> getUnitCodes(String courseKey, String year, String semester) {
    return curriculum[courseKey]?[year]?[semester] ?? [];
  }

  /// Convert unit codes to names using UnitCatalog
  static List<String> getUnitNames(List<String> codes) {
    return codes.map((c) => UnitCatalog.units[c] ?? c).toList();
  }
}

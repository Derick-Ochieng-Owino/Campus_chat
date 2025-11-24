// lib/core/constants/campus_hierarchy.dart
class CampusHierarchy {
  static final Map<String, Map<String, Map<String, List<String>>>> hierarchy = {
    'COETEC': {
      'School of Computing & IT': {
        'Information Technology': ['BIT', 'BBIT'],
        'Computing': ['COMPUTER_SCIENCE'],
      },
      'School of Civil, Env. & Geospatial Eng.': {
        'Civil Eng': ['BSC_CIVIL'],
      },
    },

    'COHRED': {
      'School of Business': {
        'Business Administration': ['BCOM'],
        'Business Information Technology': ['BBIT'],
      },
    },

    'COPAS': {
      'School of Computing & IT': {
        'Computing': ['COMPUTER_SCIENCE'],
      },
    },

    'COANRE': {
      'School of Agriculture & Env. Sciences': {
        'Horticulture': ['BSC_AGRIC'],
      },
    },

    'COHES': {
      'School of Medicine': {
        'Medicine & Surgery': ['MBCHB'],
      },
    },
  };
}

// lib/core/constants/campus_hierarchy_clean.dart
class CampusHierarchy {
  static final Map<String, Map<String, Map<String, List<String>>>> hierarchy = {
    'COHRED': {
      'School of Business': {
        'Business Administration': ['BCOM', 'DIP_BUS', 'CERT_BUS'],
        'Business Information Technology': ['BBIT', 'BIT'],
        'Economics, Accounting & Finance': ['BSC_ECON', 'BSC_BAF']
      }
    },

    'COPAS': {
      'School of Computing & IT': {
        'Information Technology': ['BIT'],
        'Computing': ['COMPUTER_SCIENCE', 'DATA_SCIENCE'],
      }
    },

    // other colleges: copy your previous structure but replace long course names with keys
  };
}

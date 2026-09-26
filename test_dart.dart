
void main() {
  int _getSeniorityRank(String idNumber) {
    final match = RegExp(r'\d+').firstMatch(idNumber);
    if (match != null) {
      String digits = match.group(0)!;
      int num = int.parse(digits);
      if (num < 100) return num + 200000;
      if (num < 1000) return num + 100000;
      if (digits.startsWith('10')) return num + 50000;
      return num;
    }
    return 999999;
  }
  
  List<String> ids = ['1051', '7083', '8262'];
  ids.sort((a, b) => _getSeniorityRank(a).compareTo(_getSeniorityRank(b)));
  print(ids);
}

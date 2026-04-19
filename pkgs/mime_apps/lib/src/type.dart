
class Mimelist {
  final Map<String, Set<String>> added;
  final Map<String, Set<String>> removed;
  final Map<String, Set<String>> defaults;

  Mimelist.empty() : added = {}, removed = {}, defaults = {};
}

// class Association {
//   final String mime;
//   Set<String> desktops;

//   Association(this.mime, String desktops) : desktops = desktops.split(";").toSet();

//   @override
//   bool operator ==(covariant Association other) {
//     return mime == other.mime;
//   }

//   @override
//   int get hashCode => mime.hashCode;
// }

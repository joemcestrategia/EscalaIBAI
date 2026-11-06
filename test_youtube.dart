import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  try {
    print('Testing YouTube Explode locally...');
    var searchResults = await yt.search.search('Louvor Aline Barros');
    for (var video in searchResults.take(3)) {
      print('Video: ${video.title} | URL: ${video.url}');
    }
    print('SUCCESS!');
  } catch (e) {
    print('Error: $e');
  } finally {
    yt.close();
  }
}

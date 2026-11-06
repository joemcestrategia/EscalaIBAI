import 'package:test/test.dart';
import 'package:escala_ibai/core/utils/titulo_normalizer.dart';

void main() {
  group('normalizarTexto', () {
    test('remove acentos', () {
      expect(normalizarTexto('Tudo é Perda'), 'tudo e perda');
    });
    test('converte caixa alta', () {
      expect(normalizarTexto('ARTISTA'), 'artista');
    });
    test('remove pontuação', () {
      expect(normalizarTexto('música, feat.'), 'musica feat');
    });
  });

  group('limparTitulo', () {
    test('remove conteúdo entre parênteses', () {
      final r = limparTitulo('Nome da Música (Ao Vivo)');
      expect(r.trim(), 'Nome da Música');
    });
    test('remove conteúdo entre colchetes', () {
      final r = limparTitulo('Nome da Música [Lyric Video]');
      expect(r.trim(), 'Nome da Música');
    });
    test('remove feat.', () {
      final r = limparTitulo('Música feat. Artista 2');
      expect(r.toLowerCase().contains('feat'), isFalse);
    });
    test('remove sufixo pós-pipe', () {
      final r = limparTitulo('Música - Artista | Clipe Oficial');
      expect(r.contains('Clipe'), isFalse);
    });
    test('remove emojis', () {
      final r = limparTitulo('Música 🎵 Incrível');
      expect(r.contains('🎵'), isFalse);
    });
  });

  group('extrairDoTituloYt', () {
    test('canal Topic extrai artista do canal', () {
      final r = extrairDoTituloYt(
        tituloYt: 'Tudo é Perda',
        nomeCanal: 'Felipe Rodrigues - Topic',
      );
      expect(r.artista, 'Felipe Rodrigues');
      expect(r.titulo, 'Tudo é Perda');
      expect(r.origem, 'descricao_youtube');
    });

    test('descrição auto-gerada extrai título e artista', () {
      const descricao = '''Provided to YouTube by Universal Music Group

Tudo é Perda · Felipe Rodrigues · Álbum do Artista

℗ 2023 Universal

Released on: 2023-01-01''';
      final r = extrairDoTituloYt(
        tituloYt: 'Tudo é Perda (Ao Vivo) - Felipe Rodrigues | Clipe Oficial',
        nomeCanal: 'Felipe Rodrigues',
        descricao: descricao,
      );
      expect(r.titulo, 'Tudo é Perda');
      expect(r.artista, 'Felipe Rodrigues');
      expect(r.origem, 'descricao_youtube');
    });

    test('separador traço com canal correspondente', () {
      final r = extrairDoTituloYt(
        tituloYt: 'Fernandinho - Nada Além do Sangue [Lyric Video]',
        nomeCanal: 'Fernandinho',
      );
      expect(normalizarTexto(r.titulo).contains('nada alem do sangue'), isTrue);
    });

    test('separador traço genérico gospel BR (título antes do traço)', () {
      final r = extrairDoTituloYt(
        tituloYt: 'Essência da Adoração - Gabi Sampaio | Clipe Oficial',
        nomeCanal: 'Gabi Sampaio Oficial',
      );
      expect(normalizarTexto(r.titulo).contains('essencia da adoracao'), isTrue);
    });

    test('título com caixa alta e feat.', () {
      final r = extrairDoTituloYt(
        tituloYt: 'ADORAMOS O CORDEIRO feat. Coral Jovem - Diante do Trono',
        nomeCanal: 'Diante do Trono',
      );
      expect(r.titulo.toLowerCase().contains('adoramos o cordeiro'), isTrue);
      expect(r.titulo.toLowerCase().contains('feat'), isFalse);
    });
  });

  group('similaridade (trigramas)', () {
    test('strings iguais → 1.0', () {
      expect(similaridade('adoramos cordeiro', 'adoramos cordeiro'), 1.0);
    });
    test('strings diferentes → < 0.3', () {
      expect(similaridade('adoramos cordeiro', 'fernandinho sede'), lessThan(0.3));
    });
    test('strings próximas com acento → alto', () {
      final s = similaridade('essencia da adoracao', 'essência da adoração');
      expect(s, greaterThan(0.8));
    });
    test('string com typo leve → acima do limiar', () {
      final s = similaridade('adoramos coedeiro', 'adoramos cordeiro');
      expect(s, greaterThan(kFuzzyLimiar));
    });
  });

  group('isCanalTopic', () {
    test('detecta canal Topic', () {
      expect(isCanalTopic('Felipe Rodrigues - Topic'), isTrue);
      expect(isCanalTopic('Gabi Sampaio - topic'), isTrue);
    });
    test('canal normal não é Topic', () {
      expect(isCanalTopic('Felipe Rodrigues Oficial'), isFalse);
    });
  });
}

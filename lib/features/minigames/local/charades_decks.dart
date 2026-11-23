/// The offline "charadas" word bank: Peruvian categories, ready to play with no
/// account and no network.
///
/// The server's `minigame_prompts` table already carries a `charades` pack, but
/// the pass-the-phone game must work on a brand-new install (and in a room with
/// no signal), so the words that matter ship in the app.
///
/// Rules of the bank: one to three words per card, no punctuation that would
/// give the answer away, nothing that can only be mimed by reading the screen.
/// Categories are the ones a Peruvian table actually improvises.
library;

import 'dart:math';

import 'package:flutter/foundation.dart';

/// One charades category and its words.
@immutable
class CharadesDeck {
  const CharadesDeck({
    required this.id,
    required this.labelKey,
    required this.emoji,
    required this.words,
  });

  /// Stable id — also the `category` written on a cached prompt.
  final String id;

  /// l10n getter suffix, resolved by the lobby (`charadesCategory<suffix>`).
  final String labelKey;

  /// One glyph for the deck chip.
  final String emoji;

  final List<String> words;
}

/// Every deck the offline charades game can draw from.
const List<CharadesDeck> kCharadesDecks = [
  CharadesDeck(
    id: 'animales',
    labelKey: 'Animals',
    emoji: '🐾',
    words: [
      'llama',
      'alpaca',
      'vicuña',
      'cuy',
      'gallito de las rocas',
      'delfín rosado',
      'oso de anteojos',
      'cóndor',
      'puma',
      'otorongo',
      'lobo de río',
      'mono choro',
      'pingüino de Humboldt',
      'pelícano',
      'lobo marino',
      'vizcacha',
      'zorro andino',
      'paiche',
      'anaconda',
      'tucán',
      'guacamayo',
      'perezoso',
      'chinchilla',
      'caimán negro',
      'pudú',
    ],
  ),
  CharadesDeck(
    id: 'cultura_pop',
    labelKey: 'Pop',
    emoji: '🎤',
    words: [
      'Chabuca Granda',
      'Yma Sumac',
      'Juan Diego Flórez',
      'Eva Ayllón',
      'Gian Marco',
      'Pedro Suárez-Vértiz',
      'Zambo Cavero',
      'Óscar Avilés',
      'Susana Baca',
      'Chacalón',
      'Los Shapis',
      'Los Mirlos',
      'Los Destellos',
      'Grupo 5',
      'Hermanos Yaipén',
      'Deyvis Orosco',
      'Corazón Serrano',
      'Agua Marina',
      'Tony Rosado',
      'Tongo',
      'Wendy Sulca',
      'La Tigresa del Oriente',
      'Inca Kola',
      'Magaly TV',
    ],
  ),
  CharadesDeck(
    id: 'literatura',
    labelKey: 'Literature',
    emoji: '📚',
    words: [
      'César Vallejo',
      'Mario Vargas Llosa',
      'José María Arguedas',
      'Julio Ramón Ribeyro',
      'Alfredo Bryce Echenique',
      'Ricardo Palma',
      'Clorinda Matto de Turner',
      'José Carlos Mariátegui',
      'Blanca Varela',
      'Santiago Roncagliolo',
      'Alonso Cueto',
      'Los ríos profundos',
      'La ciudad y los perros',
      'Conversación en La Catedral',
      'La casa verde',
      'Tradiciones peruanas',
      'Aves sin nido',
      'Redoble por Rancas',
      'Un mundo para Julius',
      'La palabra del mudo',
      'Yawar Fiesta',
      'Paco Yunque',
      'Los heraldos negros',
      'Trilce',
    ],
  ),
  CharadesDeck(
    id: 'arte',
    labelKey: 'Art',
    emoji: '🎨',
    words: [
      'José Sabogal',
      'Pancho Fierro',
      'Julia Codesido',
      'Víctor Humareda',
      'Fernando de Szyszlo',
      'Tilsa Tsuchiya',
      'Museo Larco',
      'MALI',
      'Museo de la Nación',
      'Líneas de Nazca',
      'Candelabro de Paracas',
      'Manto de Paracas',
      'Huaco retrato',
      'Estela Raimondi',
      'Obelisco Tello',
      'Chavín de Huántar',
      'Machu Picchu',
      'Kuélap',
      'Chan Chan',
      'Señor de Sipán',
      'Dama de Cao',
      'Torito de Pucará',
      'Retablo ayacuchano',
      'Mate burilado',
    ],
  ),
  CharadesDeck(
    id: 'deportes',
    labelKey: 'Sports',
    emoji: '⚽',
    words: [
      'Paolo Guerrero',
      'Jefferson Farfán',
      'Claudio Pizarro',
      'Nolberto Solano',
      'Teófilo Cubillas',
      'Hugo Sotil',
      'Héctor Chumpitaz',
      'César Cueto',
      'Pedro Gallese',
      'Luis Advíncula',
      'Renato Tapia',
      'André Carrillo',
      'Christian Cueva',
      'Gianluca Lapadula',
      'Edison Flores',
      'Alianza Lima',
      'Universitario',
      'Sporting Cristal',
      'Cienciano',
      'FBC Melgar',
      'Sport Boys',
      'Gladys Tejeda',
      'Kimberly García',
      'Diego Elías',
      'Stefano Peschiera',
      'Cecilia Tait',
    ],
  ),
  CharadesDeck(
    id: 'drama',
    labelKey: 'Drama',
    emoji: '📺',
    words: [
      'Al fondo hay sitio',
      'De vuelta al barrio',
      'Ven baila quinceañera',
      'Luz de Luna',
      'Mil oficios',
      'Así es la vida',
      'Esto es guerra',
      'Combate',
      'Yo soy',
      'La voz Perú',
      'El wasap de JB',
      'Beto a saber',
      'La paisana Jacinta',
      'Asu mare',
      'La teta asustada',
      'Wiñaypacha',
      'Retablo',
      'Canción sin nombre',
      'Días de Santiago',
      'Paloma de papel',
      'Magaly Solier',
      'Claudia Llosa',
      'Mónica Sánchez',
      'Diego Bertie',
    ],
  ),
  CharadesDeck(
    id: 'comida',
    labelKey: 'Food',
    emoji: '🍽️',
    words: [
      'ceviche',
      'lomo saltado',
      'ají de gallina',
      'arroz con pollo',
      'papa a la huancaína',
      'causa limeña',
      'anticuchos',
      'pollo a la brasa',
      'arroz chaufa',
      'tallarín saltado',
      'sopa criolla',
      'aguadito',
      'carapulcra',
      'tacu tacu',
      'rocoto relleno',
      'juane',
      'tacacho con cecina',
      'pachamanca',
      'cuy chactado',
      'chicharrón',
      'tamales',
      'humitas',
      'picarones',
      'suspiro a la limeña',
      'mazamorra morada',
      'pisco sour',
      'chilcano',
      'chicha morada',
      'emoliente',
      'lúcuma',
      'granadilla',
      'chirimoya',
      'camu camu',
      'maracuyá',
    ],
  ),
];

/// One dealt hand: the words of one or more decks, shuffled, and a draw cursor.
///
/// A turn plays through the hand without repeating a word; when the hand runs
/// out the turn ends early (a table that guesses 40 words deserves the win).
class CharadesHand {
  CharadesHand._(this.decks, this.words, this._order, this._cursor);

  /// Deals one hand from [decks] (`[]` = every deck). Merging them is what the
  /// lobby's "todas" category means.
  factory CharadesHand.deal(List<CharadesDeck> decks, {Random? random}) {
    final source = decks.isEmpty ? kCharadesDecks : decks;
    // Deduplicated: two decks can name the same thing (a footballer in both
    // sports and pop culture), and a repeated card inside one turn is dead air.
    final words = <String>{for (final deck in source) ...deck.words}.toList();
    final order = List<int>.generate(words.length, (i) => i)
      ..shuffle(random ?? Random());
    return CharadesHand._(source, words, order, 0);
  }

  final List<CharadesDeck> decks;
  final List<String> words;
  final List<int> _order;
  int _cursor;

  /// Words still undealt in this hand.
  int get remaining => _order.length - _cursor;

  bool get isEmpty => remaining <= 0;

  /// The next word, or null when the hand is exhausted.
  String? draw() {
    if (isEmpty) return null;
    return words[_order[_cursor++]];
  }

  /// Re-deals every word (a rematch over the same deck).
  void reset({Random? random}) {
    _order.shuffle(random ?? Random());
    _cursor = 0;
  }
}

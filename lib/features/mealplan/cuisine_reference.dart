/// Reference dishes per cuisine, taken from Section 4.2 of the
/// implementation guide. Passed into the AI prompt so meal plan
/// generation is grounded in real, recognizable dishes for each
/// cuisine rather than inventing unfamiliar names.
///
/// NOTE: this is a starting point, not the guide's full "local food
/// database" requirement (4.1, bullet 17) — that calls for a real
/// database mapping every dish to verified calorie/macro data before
/// the AI ever sees it. This is a lighter, prompt-level grounding step;
/// worth flagging to your mentor as a scoped-down version of 4.1/4.2.
class CuisineReference {
  static const Map<String, List<String>> dishes = {
    'Indian': [
      'Dal tadka', 'Palak paneer', 'Roti', 'Brown rice', 'Sabzi',
      'Chicken curry', 'Rajma', 'Chole', 'Idli-sambar', 'Poha',
      'Oats upma', 'Grilled tandoori chicken', 'Raita',
    ],
    'Chinese': [
      'Congee (jook)', 'Har gow', 'Siu mai', 'Char siu (BBQ pork)',
      'Wonton noodle soup', 'Steamed fish', 'Stir-fried vegetables',
      'Fried rice', 'Hot pot broth', 'Tofu', 'Bok choy',
    ],
    'Malaysian': [
      'Nasi lemak', 'Roti canai with dhal', 'Laksa', 'Mee goreng',
      'Rendang', 'Satay', 'Teh tarik', 'Char kway teow',
    ],
    'Mexican': [
      'Corn tortilla', 'Grilled chicken fajitas', 'Black bean tacos',
      'Guacamole', 'Pico de gallo', 'Chicken burrito bowl', 'Ceviche',
      'Enchiladas', 'Arroz rojo',
    ],
    'Middle Eastern': [
      'Grilled kofta', 'Hummus', 'Pita bread', 'Fattoush salad',
      'Grilled chicken shawarma wrap', 'Tabbouleh', 'Lentil soup',
      'Falafel', 'Labneh', 'Mujaddara',
    ],
    'Western': [
      'Grilled salmon', 'Chicken breast', 'Quinoa salad',
      'Egg white omelette', 'Greek yogurt parfait', 'Whole grain pasta',
      'Broccoli', 'Sweet potato', 'Avocado toast', 'Overnight oats',
    ],
    'Japanese': [
      'Steamed rice', 'Miso soup', 'Grilled salmon teriyaki', 'Edamame',
      'Sashimi', 'Onigiri', 'Tofu miso', 'Chicken yakitori', 'Soba noodles',
    ],
    'Vietnamese': [
      'Pho', 'Goi cuon (spring rolls)', 'Bun bo hue', 'Banh mi',
      'Com tam', 'Lemongrass grilled chicken', 'Broken rice plates',
    ],
  };

  /// Builds a short reference block for the given cuisines, to embed
  /// in the AI prompt. Falls back to a general note if none selected.
  static String referenceBlockFor(List<String> cuisines) {
    if (cuisines.isEmpty) {
      return 'No specific cuisine set — use a healthy mixed international selection.';
    }
    return cuisines.map((c) {
      final list = dishes[c];
      if (list == null) return c;
      return '$c: ${list.join(', ')}';
    }).join('\n');
  }
}
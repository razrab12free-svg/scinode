/// Шаблоны частых формул (названия — строки `ft.<key>`).
library;

enum FormulaCategory { math, physics, stats, chem }

class FormulaTemplate {
  const FormulaTemplate(this.key, this.category, this.tex);
  final String key;
  final FormulaCategory category;
  final String tex;
}

const formulaTemplates = <FormulaTemplate>[
  // Математика.
  FormulaTemplate(
      'quad', FormulaCategory.math, r'x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}'),
  FormulaTemplate('pyth', FormulaCategory.math, r'a^2 + b^2 = c^2'),
  FormulaTemplate('deriv', FormulaCategory.math,
      r"f'(x) = \lim_{h \to 0} \frac{f(x+h) - f(x)}{h}"),
  FormulaTemplate('taylor', FormulaCategory.math,
      r'f(x) = \sum_{n=0}^{\infty} \frac{f^{(n)}(a)}{n!}(x-a)^n'),
  FormulaTemplate('euler', FormulaCategory.math, r'e^{i\pi} + 1 = 0'),
  FormulaTemplate(
      'parts', FormulaCategory.math, r'\int u\,dv = uv - \int v\,du'),
  FormulaTemplate('matrix', FormulaCategory.math,
      r'A = \begin{pmatrix} a_{11} & a_{12} \\ a_{21} & a_{22} \end{pmatrix}'),
  FormulaTemplate(
      'det', FormulaCategory.math, r'\det A = a_{11}a_{22} - a_{12}a_{21}'),
  // Физика.
  FormulaTemplate('newton', FormulaCategory.physics, r'\vec{F} = m\vec{a}'),
  FormulaTemplate('energy', FormulaCategory.physics, r'E = mc^2'),
  FormulaTemplate('kinetic', FormulaCategory.physics, r'E_k = \frac{mv^2}{2}'),
  FormulaTemplate(
      'gravity', FormulaCategory.physics, r'F = G\frac{m_1 m_2}{r^2}'),
  FormulaTemplate('ohm', FormulaCategory.physics, r'I = \frac{U}{R}'),
  FormulaTemplate('schrodinger', FormulaCategory.physics,
      r'i\hbar\frac{\partial}{\partial t}\Psi = \hat{H}\Psi'),
  FormulaTemplate('gas', FormulaCategory.physics, r'pV = nRT'),
  FormulaTemplate('wave', FormulaCategory.physics, r'v = \lambda \nu'),
  // Статистика.
  FormulaTemplate('mean', FormulaCategory.stats,
      r'\bar{x} = \frac{1}{n}\sum_{i=1}^{n} x_i'),
  FormulaTemplate('sd', FormulaCategory.stats,
      r's = \sqrt{\frac{1}{n-1}\sum_{i=1}^{n}(x_i - \bar{x})^2}'),
  FormulaTemplate('normal', FormulaCategory.stats,
      r'f(x) = \frac{1}{\sigma\sqrt{2\pi}}\, e^{-\frac{(x-\mu)^2}{2\sigma^2}}'),
  FormulaTemplate('bayes', FormulaCategory.stats,
      r'P(A \mid B) = \frac{P(B \mid A)\,P(A)}{P(B)}'),
  FormulaTemplate('ttest', FormulaCategory.stats,
      r't = \frac{\bar{x} - \mu_0}{s/\sqrt{n}}'),
  FormulaTemplate('pearson', FormulaCategory.stats,
      r'r = \frac{\sum (x_i - \bar{x})(y_i - \bar{y})}{\sqrt{\sum (x_i - \bar{x})^2 \sum (y_i - \bar{y})^2}}'),
  FormulaTemplate('ci', FormulaCategory.stats,
      r'\bar{x} \pm z_{\alpha/2}\frac{\sigma}{\sqrt{n}}'),
  FormulaTemplate('regression', FormulaCategory.stats,
      r'y = \beta_0 + \beta_1 x + \varepsilon'),
  // Химия и биология.
  FormulaTemplate('arrhenius', FormulaCategory.chem, r'k = A\, e^{-E_a/(RT)}'),
  FormulaTemplate(
      'ph', FormulaCategory.chem, r'\mathrm{pH} = -\log_{10}[\mathrm{H^+}]'),
  FormulaTemplate('henderson', FormulaCategory.chem,
      r'\mathrm{pH} = \mathrm{p}K_a + \log_{10}\frac{[\mathrm{A^-}]}{[\mathrm{HA}]}'),
  FormulaTemplate(
      'michaelis', FormulaCategory.chem, r'v = \frac{V_{\max}[S]}{K_m + [S]}'),
  FormulaTemplate(
      'gibbs', FormulaCategory.chem, r'\Delta G = \Delta H - T\Delta S'),
  FormulaTemplate('beer', FormulaCategory.chem, r'A = \varepsilon l c'),
  FormulaTemplate('growth', FormulaCategory.chem, r'N(t) = N_0 e^{rt}'),
  FormulaTemplate('photo', FormulaCategory.chem,
      r'6\mathrm{CO_2} + 6\mathrm{H_2O} \rightarrow \mathrm{C_6H_{12}O_6} + 6\mathrm{O_2}'),
];

/// Мои формулы из заметок: без повторов, частые и свежие первыми.
List<String> myFormulas(Iterable<String> formulas, {int limit = 40}) {
  final count = <String, int>{};
  final order = <String>[];
  for (final f in formulas) {
    final k = f.trim();
    if (k.isEmpty) continue;
    if (!count.containsKey(k)) order.add(k);
    count[k] = (count[k] ?? 0) + 1;
  }
  final first = {for (var i = 0; i < order.length; i++) order[i]: i};
  order.sort((a, b) {
    final c = count[b]!.compareTo(count[a]!);
    return c != 0 ? c : first[a]!.compareTo(first[b]!);
  });
  return order.take(limit).toList();
}

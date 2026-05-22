/// Porteiro logado.
///
/// No protótipo não há autenticação real: a sessão é fixa em [demoDoorman].
class Doorman {
  const Doorman({
    required this.name,
    required this.condominium,
    required this.email,
  });

  final String name;
  final String condominium;
  final String email;

  /// Primeiro nome, para saudações curtas.
  String get firstName => name.split(' ').first;
}

/// Sessão de demonstração usada enquanto o login real não existe.
const Doorman demoDoorman = Doorman(
  name: 'João Porteiro',
  condominium: 'Residencial Jardim das Flores',
  email: 'porteiro@logifree.com.br',
);

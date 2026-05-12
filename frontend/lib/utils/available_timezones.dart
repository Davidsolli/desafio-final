/// Lista curta de fusos brasileiros oferecidos no dropdown de notificações.
///
/// Usada pelas telas de settings de cliente e trainer. O `value` é o
/// identificador IANA enviado ao backend; o `label` é o que o usuário vê.
/// Para adicionar um novo fuso, basta acrescentar uma entrada aqui.
class TimezoneOption {
  final String value;
  final String label;
  const TimezoneOption(this.value, this.label);
}

const List<TimezoneOption> availableTimezones = <TimezoneOption>[
  TimezoneOption('America/Sao_Paulo', 'São Paulo (UTC-3)'),
  TimezoneOption('America/Belem', 'Belém (UTC-3)'),
  TimezoneOption('America/Recife', 'Recife (UTC-3)'),
  TimezoneOption('America/Cuiaba', 'Cuiabá (UTC-4)'),
  TimezoneOption('America/Manaus', 'Manaus (UTC-4)'),
  TimezoneOption('America/Rio_Branco', 'Rio Branco (UTC-5)'),
  TimezoneOption('America/Noronha', 'Fernando de Noronha (UTC-2)'),
];

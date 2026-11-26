import 'package:test/test.dart';
import 'package:vantrack_backend/cadastro/dominio/aluno.dart';
import 'package:vantrack_backend/cadastro/dominio/motorista.dart';
import 'package:vantrack_backend/cadastro/dominio/responsavel.dart';
import 'package:vantrack_backend/cadastro/dominio/usuario.dart';
import 'package:vantrack_backend/cadastro/dominio/vinculo_motorista_van.dart';

void main() {
  group('VinculoMotoristaVan (RN-012)', () {
    VinculoMotoristaVan vinculo({DateTime? fim}) => VinculoMotoristaVan(
          id: 1,
          motoristaId: 1,
          vanId: 1,
          inicio: DateTime.utc(2026, 10, 15),
          fim: fim,
        );

    test('sem data de fim está ativo', () {
      expect(vinculo().estaAtivo(), isTrue);
    });

    test('com data de fim não está ativo', () {
      expect(vinculo(fim: DateTime.utc(2026, 11)).estaAtivo(), isFalse);
    });

    test('autoriza só o motorista do vínculo', () {
      expect(vinculo().autoriza(1), isTrue);
      expect(vinculo().autoriza(2), isFalse);
    });

    test('vínculo encerrado não autoriza nem o próprio motorista', () {
      expect(vinculo(fim: DateTime.utc(2026, 11)).autoriza(1), isFalse);
    });
  });

  group('Aluno.ehMenorDeIdade (RN-009)', () {
    final hoje = DateTime(2026, 11, 14);

    test('alunos do seed: Ana é menor e Carlos é maior', () {
      final ana = Aluno(
        id: 1,
        nome: 'Ana Souza',
        dataNascimento: DateTime(2014, 3, 10),
      );
      final carlos = Aluno(
        id: 3,
        nome: 'Carlos Lima',
        dataNascimento: DateTime(2006, 5, 1),
      );

      expect(ana.ehMenorDeIdade(hoje), isTrue);
      expect(carlos.ehMenorDeIdade(hoje), isFalse);
    });

    test('no dia do aniversário de 18 anos já é maior', () {
      final aluno =
          Aluno(id: 9, nome: 'X', dataNascimento: DateTime(2008, 11, 14));

      expect(aluno.ehMenorDeIdade(DateTime(2026, 11, 13)), isTrue);
      expect(aluno.ehMenorDeIdade(DateTime(2026, 11, 14, 8)), isFalse);
    });
  });

  group('Usuario', () {
    final joao = Motorista(
      id: 1,
      nome: 'João Pereira',
      login: 'joao.pereira',
      telefone: '(44) 99901-0001',
      cnh: '01234567890',
    );
    final maria = Responsavel(
      id: 1,
      nome: 'Maria Souza',
      login: 'maria.souza',
      telefone: '(44) 99902-0001',
      email: 'maria.souza@exemplo.com',
    );

    test('motorista e responsável são usuários com o seu papel', () {
      expect(joao, isA<Usuario>());
      expect(joao.papel, Papel.motorista);
      expect(maria.papel, Papel.responsavel);
    });

    test('usuário sem senha cadastrada não autentica', () {
      expect(joao.autenticar('qualquer'), isFalse);
    });

    test('Papel converte o código do JSON', () {
      expect(Papel.deCodigo('MOTORISTA'), Papel.motorista);
      expect(Papel.deCodigo('RESPONSAVEL'), Papel.responsavel);
      expect(Papel.deCodigo('ADMIN'), isNull);
    });
  });
}

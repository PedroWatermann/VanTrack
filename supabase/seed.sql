-- seed.sql — Dados de teste do UC-S05 (seção 6 do backlog; Membro A, task A-04)
-- Pode rodar de novo quantas vezes quiser: apaga os dados e recria tudo.
-- Os ids são fixos para todos testarem com os mesmos valores (rota 1, alunos 1 a 4).

truncate table
  sessao, embarque, presenca, rota, ponto_parada, aluno_responsavel, aluno,
  responsavel, vinculo_motorista_van, motorista, van, empresa
  restart identity cascade;

-- 1 empresa e 1 van
insert into empresa (id, nome, cnpj) values
  (1, 'Transportes Escolares Caminho Seguro', '12.345.678/0001-90');

insert into van (id, empresa_id, placa, modelo, capacidade) values
  (1, 1, 'ABC-1D23', 'Mercedes-Benz Sprinter', 15);

-- 2 motoristas: um ATIVO na van e um SEM VÍNCULO (para testar a RN-012)
-- senha_hash fica nula: o login simplificado entra pelo id do seed (C-02 decide).
insert into motorista (id, empresa_id, nome, login, telefone, cnh) values
  (1, 1, 'João Pereira',    'joao.pereira',    '(44) 99901-0001', '01234567890'),
  (2, 1, 'Marcos Oliveira', 'marcos.oliveira', '(44) 99901-0002', '09876543210');

insert into vinculo_motorista_van (id, motorista_id, van_id, inicio, fim) values
  (1, 1, 1, now() - interval '30 days', null);

-- 4 responsáveis: dois do aluno 1, um do aluno 2 e um do aluno 4
insert into responsavel (id, nome, login, telefone, email) values
  (1, 'Maria Souza',   'maria.souza',   '(44) 99902-0001', 'maria.souza@exemplo.com'),
  (2, 'Paulo Souza',   'paulo.souza',   '(44) 99902-0002', 'paulo.souza@exemplo.com'),
  (3, 'Fernanda Reis', 'fernanda.reis', '(44) 99902-0003', 'fernanda.reis@exemplo.com'),
  (4, 'Ricardo Alves', 'ricardo.alves', '(44) 99902-0004', 'ricardo.alves@exemplo.com');

-- 4 alunos. Carlos Lima é maior de idade e não tem responsável (A1 do UC-I02).
insert into aluno (id, nome, data_nascimento, situacao_cadastro) values
  (1, 'Ana Souza',    date '2014-03-10', 'ATIVO'),
  (2, 'Beatriz Reis', date '2015-07-22', 'ATIVO'),
  (3, 'Carlos Lima',  date '2006-05-01', 'ATIVO'),
  (4, 'Bruno Alves',  date '2013-09-15', 'ATIVO');

insert into aluno_responsavel (aluno_id, responsavel_id) values
  (1, 1),
  (1, 2),
  (2, 3),
  (4, 4);

-- 4 paradas
insert into ponto_parada (id, endereco, latitude, longitude) values
  (1, 'Rua das Acácias, 100',  -23.4205, -51.9331),
  (2, 'Avenida Brasil, 1500',  -23.4230, -51.9380),
  (3, 'Rua das Flores, 210',   -23.4262, -51.9412),
  (4, 'Rua Santos Dumont, 45', -23.4290, -51.9450);

-- Rota de HOJE, ida, ativa. "Hoje" é a data de Brasília: o servidor do Supabase
-- roda em UTC, e current_date viraria o dia seguinte depois das 21h.
insert into rota (id, van_id, data, trajeto, horario_previsto, situacao) values
  (1, 1, (now() at time zone 'America/Sao_Paulo')::date, 'IDA', time '06:30', 'ATIVA');

-- Presenças: alunos 1 a 3 confirmados; aluno 4 ausente (não pode aparecer na lista)
insert into presenca
  (id, rota_id, aluno_id, ponto_parada_id, ordem, situacao, data_hora_confirmacao, data_hora_cancelamento)
values
  (1, 1, 1, 1, 1, 'CONFIRMADO', now() - interval '12 hours', null),
  (2, 1, 2, 2, 2, 'CONFIRMADO', now() - interval '12 hours', null),
  (3, 1, 3, 3, 3, 'CONFIRMADO', now() - interval '12 hours', null),
  (4, 1, 4, 4, 4, 'AUSENTE',    now() - interval '12 hours', now() - interval '10 hours');

-- Como os ids foram fixados à mão, avança as sequências para os próximos inserts.
-- Fica num bloco DO (sem SELECT solto) porque o pacote postgres do Dart, usado
-- pelo reset_db.dart, não aceita vários comandos que devolvem linhas no mesmo arquivo.
do $$
declare
  tabela text;
begin
  foreach tabela in array array[
    'empresa', 'van', 'motorista', 'vinculo_motorista_van', 'responsavel',
    'aluno', 'ponto_parada', 'rota', 'presenca'
  ] loop
    execute format(
      'select setval(pg_get_serial_sequence(%L, ''id''), (select max(id) from %I))',
      tabela, tabela
    );
  end loop;
end
$$;

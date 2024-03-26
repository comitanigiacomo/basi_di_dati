-- PROCEDURE

-- TRASFORMA UNO STUDENTE IN UN EX_STUDENTE
CREATE OR REPLACE PROCEDURE studentToExStudent (
    _id uuid,
    _motivo TipoMotivo
)
  LANGUAGE plpgsql
  AS $$
    DECLARE
        matricola_ex_studente INTEGER;
        cdl INTEGER;
    BEGIN
        SELECT matricola INTO matricola_ex_studente
        FROM universal.studenti
        WHERE id = _id;

        SELECT corso_di_laurea INTO cdl
        FROM universal.studenti
        WHERE id = _id;

        -- Aggiorna il tipo dell'utente a 'ex_studente'
        UPDATE universal.utenti
        SET tipo = 'ex_studente'
        WHERE universal.utenti.id = _id;

        -- Inserisce i dati dell'ex studente nella tabella degli ex studenti
        INSERT INTO universal.ex_studenti (id, motivo, matricola, corso_di_laurea)
        VALUES (_id, _motivo, matricola_ex_studente, cdl);

        -- Sposta le valutazioni dello studente dalla tabella iscritti a storico_valutazioni
        INSERT INTO universal.storico_valutazioni (id, nome, cognome, matricola, insegnamento, voto,data, corso_di_laurea)
        SELECT u.id, u.nome, u.cognome, s.matricola, i.appello, i.voto,a.data, s.corso_di_laurea
        FROM universal.utenti u
        JOIN universal.studenti s ON u.id = s.id
        JOIN universal.iscritti i ON u.id = i.studente
        INNER JOIN universal.appelli AS a ON i.appello = a.codice
        WHERE u.id = _id;

        -- Rimuove lo studente dalla tabella studenti
        DELETE FROM universal.studenti
        WHERE id = _id;

        -- Rimuove le valutazioni dello studente dalla tabella iscritti
        DELETE FROM universal.iscritti
        WHERE studente = _id;

    END;
  $$;


-- INSERISCE UN NUOVO UTENTE
CREATE OR REPLACE PROCEDURE universal.insert_utente(
    nome VARCHAR(40),
    cognome VARCHAR(40),
    tipo TipoUtente,
    password VARCHAR(255)
)
LANGUAGE plpgsql
AS $$
DECLARE
    email VARCHAR(255);
    crypt_password VARCHAR(255);
BEGIN
    -- Verifica che la password soddisfi i vincoli prima della crittografia
    IF LENGTH(password) != 8 OR NOT (password ~ '[!@#$%^&*()-_+=]') THEN
        RAISE EXCEPTION 'La password deve essere lunga 8 caratteri e contenere almeno un carattere speciale.';
    END IF;

    email := universal.get_email(nome, cognome, tipo);
    crypt_password := crypt(password, gen_salt('bf')); -- Utilizzo del metodo di crittografia Blowfish
    INSERT INTO universal.utenti (nome, cognome, tipo, email, password)
    VALUES (nome, cognome, tipo, email, crypt_password);
END;
$$;

-- ELIMINA UN UTENTE.
--RICORDO CHE DEVO SFRUTTARE IL TRIGGER 'AGGIONA TABELLA', DUNQUE IN REALTA VADO AD ELIMINARE L'UTENTE DALLA SUA TABELLA OPPORTUNA IN BASE AL TIPO

CREATE OR REPLACE PROCEDURE universal.delete_utente(
    _id uuid
)
LANGUAGE plpgsql
AS $$
DECLARE
    tipo_utente TipoUtente;
BEGIN
    -- Ottieni il tipo dell'utente
    SELECT tipo INTO tipo_utente
    FROM universal.utenti
    WHERE id = _id;

    -- Elimina l'utente in base al suo tipo
    CASE tipo_utente
        WHEN 'studente' THEN
            DELETE FROM universal.studenti WHERE id = _id;
        WHEN 'ex_studente' THEN
            DELETE FROM universal.ex_studenti WHERE id = _id;
        WHEN 'docente' THEN
            DELETE FROM universal.docenti WHERE id = _id;
        WHEN 'segretario' THEN
            DELETE FROM universal.segretari WHERE id = _id;
        ELSE
            RAISE EXCEPTION 'Tipo utente non valido';
    END CASE;
END;
$$;


-- INSERISCE UN CORSO DI LAUREA
CREATE OR REPLACE PROCEDURE universal.insert_degree_course(
    _nome VARCHAR(40),
    _tipo INTEGER,
    _descrizione TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN

    INSERT INTO universal.corsi_di_laurea(nome, tipo, descrizione)
    VALUES (_nome, _tipo, _descrizione);
END;
$$;

-- INSERISCE UN INSEGNAMENTO

CREATE OR REPLACE PROCEDURE universal.insert_teaching(
    _nome VARCHAR(40),
    _descrizione TEXT,
    _anno INTEGER,
    _responsabile uuid,
    _corso_di_laurea INTEGER
)
    LANGUAGE plpgsql
    AS $$
        BEGIN
            INSERT INTO universal.insegnamenti(nome, descrizione, anno, docente_responsabile, corso_di_laurea)
            VALUES (_nome, _descrizione, _anno, _responsabile, _corso_di_laurea);
        END;
    $$;

-- INSERISCE UN APPELLO

CREATE OR REPLACE PROCEDURE universal.insert_exam_session(
    _data DATE,
    _luogo VARCHAR(40),
    _insegnamento INTEGER
)
    LANGUAGE plpgsql
    AS $$
        BEGIN
            INSERT INTO universal.appelli(data, luogo, insegnamento)
            VALUES (_data, _luogo, _insegnamento);
        END;
    $$;

-- ISCRIVE UNO STUDENTE AD UN APPELLO ( DATO IL SUO ID E APPELLO, SPERO DI AVERLO NELLA SESSIONE PHP )
CREATE OR REPLACE PROCEDURE universal.subscription(
    _id uuid,
    _appello INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    DECLARE
        codice_insegnamento INTEGER;
    BEGIN
        -- Ottieni l'insegnamento relativo all'appello specificato
        SELECT a.insegnamento INTO codice_insegnamento
        FROM universal.appelli AS a
        WHERE a.codice = _appello;

        -- Inserisci l'iscrizione dello studente all'appello d'esame
        INSERT INTO universal.iscritti (appello, studente,insegnamento, voto)
        VALUES (_appello, _id, codice_insegnamento, NULL);
    END;
END;
$$;


-- DOCENTE METTE VALUTAZIONE
CREATE OR REPLACE PROCEDURE universal.insert_grade(
    _id_studente uuid,
    _id_docente uuid,
    codice_appello INTEGER,
    _voto INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Controllo se il docente è responsabile dell'appello specificato
    IF NOT EXISTS (
        SELECT 1
        FROM universal.insegnamenti AS ins
        WHERE ins.docente_responsabile = _id_docente
    ) THEN
        RAISE EXCEPTION 'Il docente specificato non è responsabile per l''appello specificato.';
    END IF;

    -- Aggiornamento del voto dello studente nell'appello specificato
    UPDATE universal.iscritti
    SET voto = _voto
    WHERE studente = _id_studente AND appello = codice_appello;
END;
$$;

-- STUDENTE SI ISCRIVE AD UN CORSO DI LAUREA

CREATE OR REPLACE PROCEDURE universal.subsribe_to_cdl(
    _id_studente uuid,
    _codice INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE universal.studenti
    SET corso_di_laurea = _codice
    WHERE id = _id_studente;
END;
$$;

-- CAMBIA LA PASSWORD DI UN STUDENTE/EX_STUDENTE/DOCENTE/SEGRETARIO
CREATE OR REPLACE PROCEDURE universal.change_password(
    _id_utente uuid,
    _vecchia_password VARCHAR(255),
    _nuova_password VARCHAR(255)
)
LANGUAGE plpgsql
AS $$
DECLARE
    old_password VARCHAR(255);
    new_password VARCHAR(255);
BEGIN
    -- Ottieni la vecchia password crittografata dal database
    SELECT password INTO old_password
    FROM universal.utenti
    WHERE id = _id_utente;

    -- Verifica che la vecchia password sia corretta
    IF old_password IS NULL OR NOT crypt(_vecchia_password, old_password) = old_password THEN
        RAISE EXCEPTION 'La vecchia password non corrisponde.';
    END IF;

    -- Verifica che la nuova password soddisfi i vincoli prima della crittografia
    IF LENGTH(_nuova_password) != 8 OR NOT (_nuova_password ~ '[!@#$%^&*()-_+=]') THEN
        RAISE EXCEPTION 'La nuova password deve essere lunga 8 caratteri e contenere almeno un carattere speciale.';
    END IF;

    -- Crittografa la nuova password
    new_password := crypt(_nuova_password, gen_salt('bf'));

    -- Aggiorna la password nel database
    UPDATE universal.utenti
    SET password = new_password
    WHERE id = _id_utente;
END;
$$;
-- DISISCRIZIONE APPELLO STUDENTE
CREATE OR REPLACE PROCEDURE universal.unsubscribe_from_exam_appointment
(
    id_studente uuid,
    codice_appello INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Verifica se lo studente è iscritto all'appello selezionato
    IF NOT EXISTS (SELECT 1 FROM universal.iscritti WHERE studente = id_studente AND appello = codice_appello) THEN
        RAISE EXCEPTION 'Non sei iscritto all''appello selezionato.';
    END IF;

    -- Elimina l'iscrizione dello studente all'appello
    DELETE FROM universal.iscritti WHERE studente = id_studente AND appello = codice_appello;
END;
$$;

-- ISCRIZIONE CORSO DI LAURERA STUDENTE

CREATE OR REPLACE PROCEDURE universal.subscribe_to_cdl
(
    id_studente uuid,
    codice_cdl INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Verifica se lo studente è iscritto al corso di laurea selezionato
    IF EXISTS (SELECT 1 FROM universal.studenti AS s WHERE s.corso_di_laurea = codice_cdl AND s.id = id_studente) THEN
        RAISE EXCEPTION 'sei gia iscritto al corso di laurea selezionato.';
    END IF;

    -- Iscrive lo studente al cdl selezionato
    UPDATE universal.studenti
    SET corso_di_laurea = codice_cdl
    WHERE id = id_studente;
END;
$$;

-- DISISCRIZIONE CORSO DI LAUREA STUDENTE

CREATE OR REPLACE PROCEDURE universal.unsubscribe_to_cdl
(
    id_studente uuid,
    codice_cdl INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Verifica se lo studente è iscritto al corso di laurea selezionato
    IF  NOT EXISTS (SELECT 1 FROM universal.studenti AS s WHERE s.corso_di_laurea = codice_cdl AND s.id = id_studente) THEN
        RAISE EXCEPTION 'non sei iscritto al corso di laurea selezionato.';
    END IF;
    -- disiscrive lo studente dal cdl selezionato
    UPDATE universal.studenti
    SET corso_di_laurea = NULL
    WHERE id = id_studente AND corso_di_laurea = codice_cdl;
END;
$$;

-- CREAZIONE APPELLO DOCENTE
CREATE OR REPLACE PROCEDURE universal.create_exam_session
(
    id_docente uuid,
    _data DATE,
    _luogo VARCHAR(40),
    _insegnamento INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    responsabile uuid;
BEGIN
    -- Verifica che il docente sia il responsabile dell'insegnamento
    SELECT docente_responsabile INTO responsabile
    FROM universal.insegnamenti
    WHERE codice = _insegnamento;

    IF responsabile <> id_docente THEN
        RAISE EXCEPTION 'Non sei il responsabile di questo insegnamento';
    END IF;

    -- Verifica se esiste già un appello nella stessa data e luogo
    IF EXISTS (SELECT 1 FROM universal.appelli WHERE data = _data AND luogo = _luogo) THEN
        RAISE EXCEPTION 'Esiste già un appello in quel giorno e luogo.';
    END IF;

    -- Crea l'appello
    INSERT INTO universal.appelli (data, luogo, insegnamento)
    VALUES (_data, _luogo, _insegnamento);
END;
$$;

 -- CANCELLAZIONE APPELLO DOCENTE

CREATE OR REPLACE PROCEDURE universal.delete_exam_session
(
    id_docente uuid,
    _data DATE,
    _luogo VARCHAR(40),
    _insegnamento INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    responsabile uuid;
BEGIN
    -- Verifica che il docente sia il responsabile dell'insegnamento
    SELECT docente_responsabile INTO responsabile
    FROM universal.insegnamenti
    WHERE codice = _insegnamento;

    IF responsabile <> id_docente THEN
        RAISE EXCEPTION 'Non sei il responsabile di questo insegnamento';
    END IF;

    -- Verifica se esiste già un appello nella stessa data e luogo
    IF NOT EXISTS (SELECT 1 FROM universal.appelli WHERE data = _data AND luogo = _luogo) THEN
        RAISE EXCEPTION 'NON esiste già un appello in quel giorno e luogo.';
    END IF;

    -- Cancella l'appello
    DELETE FROM universal.appelli AS a
    WHERE
        a.data = _data
      AND a.luogo = _luogo
      AND a.insegnamento = _insegnamento;
END;
$$;

-- CREAZIONE STUDENTE SEGRETARIO
CREATE OR REPLACE PROCEDURE universal.delete_utente(
    _id uuid
)
LANGUAGE plpgsql
AS $$
DECLARE
    tipo_utente TipoUtente;
BEGIN
    -- Ottieni il tipo dell'utente
    SELECT tipo INTO tipo_utente
    FROM universal.utenti
    WHERE id = _id;

    -- Elimina l'utente in base al suo tipo
    CASE tipo_utente
        WHEN 'studente' THEN
            DELETE FROM universal.studenti WHERE id = _id;
        WHEN 'ex_studente' THEN
            DELETE FROM universal.ex_studenti WHERE id = _id;
        WHEN 'docente' THEN
            DELETE FROM universal.docenti WHERE id = _id;
        WHEN 'segretario' THEN
            DELETE FROM universal.segretari WHERE id = _id;
        ELSE
            RAISE EXCEPTION 'Tipo utente non valido';
    END CASE;
END;
$$;

-- SEGRETARIO CAMBIA DOCENTE RESPONSABILE DI UN INSEGNAMENTO
CREATE OR REPLACE PROCEDURE universal.change_course_responsible_teacher
(
    _id_nuovo_docente uuid,
    codice_insegnamento INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
BEGIN

    IF EXISTS (SELECT 1 FROM universal.insegnamenti AS ins WHERE ins.codice = codice_insegnamento AND ins.docente_responsabile = _id_nuovo_docente ) THEN
        RAISE EXCEPTION 'Sei già il responsabile di questo corso';
    end if;
    -- Ottieni il tipo dell'utente
    UPDATE universal.insegnamenti AS ins
    SET docente_responsabile = _id_nuovo_docente
    WHERE ins.codice = codice_insegnamento;
END;
$$;

-- SEGRETARIO MODIFICA STUDENTE

-- SEGRETARIO MODIFICA DOCENTE

-- SEGRETARIO MODIFICA CALENDARIO APPELLI


-- SEGRETARIO MODIFICA SEGRETARIO

-- SEGRETARIO MODIFICA CORSO DI LAUREA

-- SEGRETARIO ELIMINA CORSO DI LAUREA


-- SEGRETARIO MODIFICA NUOVO INSEGNAMENTO

-- SEGRETARIO ELIMINA INSEGNAMENTO

-- SEGRETARIO MODIFICA APPELLO

-- SEGRETARIO ELIMINA APPELLO

SET search_path TO bancaDelTempo;

-- Il campo saldo ore di utenti è calcolato e si ottiene dalle durate delle prestazioni di attività di categorie non simmetriche

CREATE OR REPLACE FUNCTION prenotazioneInserita()
RETURNS TRIGGER
AS
$$
DECLARE
	ore NUMERIC(5,2);
	prenotato VARCHAR(50);
	prenotante VARCHAR(50);
	tipo CHAR(1);
	ignoraPrestazione BOOL;
BEGIN	
	CREATE OR REPLACE TEMP VIEW attivitaSvolta AS
		(SELECT prenotazione.codice, prenotazione.durata, prenotazione.mailUtente mailprenotante, attivita.mailUtente mailprenotato, tipoDisponibilita, simmetrica
			   FROM prenotazione
			   JOIN attivita ON codiceattivita = attivita.codice);
	
	ignoraPrestazione := (SELECT simmetrica FROM attivitaSvolta WHERE codice = NEW.codiceprenotazione LIMIT 1);
	IF (ignoraPrestazione) THEN 
		RETURN NEW;
	END IF;
	
	prenotante := (SELECT mailprenotante FROM attivitaSvolta WHERE codice = NEW.codiceprenotazione LIMIT 1);
	prenotato := (SELECT mailprenotato FROM attivitaSvolta WHERE codice = NEW.codiceprenotazione LIMIT 1);
	tipo := (SELECT tipoDisponibilita FROM attivitaSvolta WHERE codice = NEW.codiceprenotazione LIMIT 1);
	ore := (SELECT durata FROM attivitaSvolta WHERE codice = NEW.codiceprenotazione LIMIT 1);		   	

	RAISE NOTICE 'ante % ato % tipo % ore%',prenotante,prenotato,tipo,ore;

	IF (tipo = 'O')
	THEN
		UPDATE utente
		SET saldoOre = saldoOre + ore
		WHERE mail = prenotato;
		
		UPDATE utente
		SET saldoOre = saldoOre - ore
		WHERE mail = prenotante;
	ELSEIF (tipo = 'R')
	THEN
		UPDATE utente
		SET saldoOre = saldoOre - ore
		WHERE mail = prenotato;
		
		UPDATE utente
		SET saldoOre = saldoOre + ore
		WHERE mail = prenotante;
	END IF;

	RETURN NEW;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER prestazioneInserita 
AFTER INSERT ON prestazione
FOR EACH ROW
EXECUTE PROCEDURE prenotazioneInserita(); 

-- Gli utenti aventi il saldo ore inferiore a -5 non possono richiedere una prestazione
-- Non è possibile che un utente effettui una prenotazione per un’attività offerta da quello stesso utente
-- Gli utenti possono essere oggetto di una prenotazione (come offerenti o riceventi) di un’Attività solamente se esiste una disponibilità tra quell’utente e l’attività (come offerente o ricevente) 
-- Gli utenti sospesi non possono richiedere, o essere richiesti, per una prenotazione

CREATE OR REPLACE FUNCTION beforePrenotazioneInserita()
RETURNS TRIGGER
AS
$$
DECLARE
	cat INTEGER := (SELECT attivita.CODICEcategorizzazione FROM attivita WHERE attivita.codice = NEW.codiceAttivita);
	tipo CHAR(1) := (SELECT attivita.tipoDisponibilita FROM attivita WHERE attivita.codice = NEW.codiceAttivita);
	mailPrenotato VARCHAR(50) := (SELECT attivita.mailUtente FROM attivita WHERE attivita.codice = NEW.codiceAttivita);
	disponibilitaPrenotante CHAR(1);
	del BOOLEAN := (SELECT attivita.eliminata FROM attivita WHERE attivita.codice = NEW.codiceAttivita);
BEGIN
	IF(del)
	THEN
		RAISE EXCEPTION 'Questa attività non è più disponibile';
	END IF;

	IF(true = ANY (SELECT sospeso FROM utente WHERE mail = mailPrenotato OR mail = NEW.mailutente) )   
	THEN
		RAISE EXCEPTION 'Non è possibile che un utente effettui prenotazioni o sia prenotato se è sospeso';
	END IF;
		
	IF((SELECT (saldoOre < -5) FROM utente WHERE mail = NEW.mailutente LIMIT 1) AND tipo = 'O')
	THEN
		RAISE EXCEPTION 'Non è possibile che un utente effettui una prenotazione come richiedente se ha saldo ore inferiore a -5';
	END IF;
		
	IF(NEW.mailUtente = mailPrenotato)
	THEN
		RAISE EXCEPTION 'Non è possibile che un utente effettui una prenotazione a sé stesso';
	END IF;
	
	disponibilitaPrenotante := (SELECT tipodisponibilita FROM attivita WHERE mailUtente = NEW.mailutente AND CODICEcategorizzazione = cat);
	
	IF((disponibilitaPrenotante IS NULL) OR (tipo = 'R' AND disponibilitaPrenotante <> 'O' OR tipo = 'O' AND disponibilitaPrenotante <> 'R'))
	THEN
		RAISE EXCEPTION 'Non è possibile che un utente effettui una prenotazione se non ha la categoria indicata nella sua lista di bisogni / disponibilità';
	END IF;
	
	RETURN NEW;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER beforePrenotazioneInserita
BEFORE INSERT ON prenotazione
FOR EACH ROW
EXECUTE PROCEDURE beforePrenotazioneInserita();

-- Non è possibile generare una prestazione in relazione con una prenotazione non accettata

CREATE OR REPLACE FUNCTION beforePrestazioneInserita()
RETURNS TRIGGER
AS
$$
DECLARE
BEGIN	
	IF((SELECT stato FROM prenotazione WHERE codice = NEW.codiceprenotazione LIMIT 1) <> 'A')
	THEN
		RAISE EXCEPTION 'Non è possibile inserire una prestazione di una prenotazione che non è stata accettata';
	END IF;
	RETURN NEW;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER beforePrestazioneInserita
BEFORE INSERT ON prestazione
FOR EACH ROW
EXECUTE PROCEDURE beforePrestazioneInserita();

/*
SELECT * FROM prenotazione WHERE stato <> 'A'
--8 "Bright.Love1985@libero.it"
INSERT INTO prestazione VALUES(8,4)
*/

-- Non è possibile aggiornate le informazioni di una prenotazione se esiste una prestazione relativa

CREATE OR REPLACE FUNCTION beforePrenotazioneAggiornata()
RETURNS TRIGGER
AS
$$
DECLARE
BEGIN	
	IF(EXISTS (SELECT * FROM prestazione WHERE codiceprenotazione = NEW.codice))
	THEN
		RAISE EXCEPTION 'Non è possibile modificare una prenotazione per la quale esiste già una prestazione';
	END IF;
	RETURN NEW;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER beforePrenotazioneAggiornata
BEFORE UPDATE ON prenotazione
FOR EACH ROW
EXECUTE PROCEDURE beforePrenotazioneAggiornata();

-- Non è possibile inserire un utente senza inserire almeno un telefono a lui legato

CREATE OR REPLACE FUNCTION afterUtenteInserito()
RETURNS TRIGGER
AS
$$
DECLARE
BEGIN
	IF(NOT EXISTS (SELECT * FROM anagrafica WHERE mail = NEW.mail))
	THEN
		DELETE FROM utente WHERE mail = NEW.mail;
		RAISE EXCEPTION 'Ogni utente deve avere le relative informazioni anagrafiche';
	END IF;
	
	IF(NOT EXISTS (SELECT * FROM telefono WHERE mail = NEW.mail))
	THEN
		DELETE FROM utente WHERE mail = NEW.mail;
		RAISE EXCEPTION 'Ogni utente deve avere almento un numero di telefono';
	END IF;
	RETURN NEW;
END;
$$
LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER afterUtenteInserito
AFTER INSERT ON utente
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW 
EXECUTE PROCEDURE afterUtenteInserito();

-- (conseguente impossibilità di eliminare l'ultimo numero di telefono di un utente)

CREATE OR REPLACE FUNCTION beforeTelefonoEliminato()
RETURNS TRIGGER
AS
$$
DECLARE
BEGIN
	IF((SELECT count(*) FROM telefono WHERE mail = OLD.mail) = 1)
	THEN
		RAISE EXCEPTION 'Ogni utente deve avere almento un numero di telefono';
	END IF;
	
	RETURN OLD;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER beforeTelefonoEliminato
BEFORE DELETE ON telefono
FOR EACH ROW 
EXECUTE PROCEDURE beforeTelefonoEliminato();

/*
-- Eliminazione di un utente

CREATE OR REPLACE FUNCTION afterUtenteEliminato()
RETURNS TRIGGER
AS
$$
DECLARE
BEGIN
	UPDATE attivita 
	SET eliminata = true
	WHERE mailutente = NEW.mail; 
	
	RETURN NEW;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER afterUtenteEliminato
AFTER DELETE ON utente
FOR EACH ROW 
EXECUTE PROCEDURE afterUtenteEliminato();

/*
SELECT * FROM UTENTE WHERE mail LIKE 'test%'
INSERT INTO ATTIVITA VALUES (DEFAULT,TRUE,NULL,NULL,NULL,'R','test@gmail.com',30,'Cagliari')
SELECT * FROM ATTIVITA WHERE MAILUTENTE = 'test@gmail.com'
DELETE FROM UTENTE WHERE MAIL = 'test@gmail.com'

SELECT * FROM eliminaUtente('test@gmail.com')
*/

/*
SELECT * FROM PRENOTAZIONE JOIN ATTIVITa ON codiceattivita = attivita.codice WHERE STATO = 'S' --218
-- rich: "XFWr9@gmail.com"
-- off: ""9HjpQ99q6@gmail.com""
-- tipo: 'O'
SELECT * FROM PRESTAZIONE WHERE CODICEPRENOTAZIONE = 226
UPDATE PRENOTAZIONE SET MAILUTENTE = 'XFWr9@gmail.com' WHERE CODICE = 227
SELECT * FROM UTENTE WHERE MAIL = 'XFWr9@gmail.com' -- perderne
SELECT * FROM utente where MAIL = '9HjpQ99q6@gmail.com' --guadagna

INSERT INTO PRESTAZIONE VALUES (227,2,'sandro CI HA SORPRESI TUTTI')
*/

/*
SELECT * FROM UTENTE WHERE SOSPESO
-- AtXHJAuWb@gmail.com
UPDATE UTENTE SET SOSPESO =  false WHERE MAIL = 'AtXHJAuWb@gmail.com'
UPDATE UTENTE SET saldoore =  20 WHERE MAIL = 'AtXHJAuWb@gmail.com'
SELECT * FROM ATTIVITA WHERE MAILUTENTE = 'AtXHJAuWb@gmail.com'
SELECT * FROM ATTIVITA WHERE CODICECATEGORIZZAZIONE = 9
-- R 8 OFFERTO DA 'RjY8OP@gmail.com' (ATT 31)
-- O 9 RICHIESTAD A '5BQqiyp6B@gmail.com' (ATT 41)
INSERT INTO ATTIVITA VALUES (default,false,NULL,NULL,NULL,'O','AtXHJAuWb@gmail.com',8,'Genova')

INSERT INTO PRENOTAZIONE VALUES (DEFAULT,'2020/1/1','20:20','LA',10,'WOW','S','AtXHJAuWb@gmail.com',32)
UPDATE ATTIVITA SET eliminata = true WHERE codice= 32

INSERT INTO PRENOTAZIONE VALUES (DEFAULT,'2020/1/1','20:20','LA',10,'WOW','S','5BQqiyp6B@gmail.com',38)
*/



select * from prestazione --5173
select * from prenotazione where codice = 5 -- 7019

UPDATE prenotazione SET annotazioni = 'lorem ipsum' WHERE codice = 5
*/

/*
INSERT INTO utente VALUES ('test@gmail.com',false,0);
INSERT INTO telefono VALUES ('+39 3330000000','test@gmail.com');

INSERT INTO utente VALUES ('test2@gmail.com',false,0);
INSERT INTO telefono VALUES ('+39 3330000000','test2@gmail.com');
INSERT INTO anagrafica VALUES ('test2@gmail.com','tizio','caio,','A','2020/01/01','qui','la')
*/


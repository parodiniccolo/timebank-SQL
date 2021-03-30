SET search_path TO bancadeltempo;

CREATE OR REPLACE TEMP VIEW saldi AS

SELECT mail, sospeso,  
	((SELECT SUM(durata)
	FROM utente
	JOIN Prenotazione ON Utente.mail = Prenotazione.mailUtente
	JOIN Prestazione ON Prenotazione.codice = prestazione.codicePrenotazione AND stato = 'A'
	JOIN Attività ON Prenotazione.codiceattività = Attività.codice
	WHERE Attività.tipoDisponibilità = 'R' AND NOT Attività.simmetrica
	AND Utente.mail = u.mail
	GROUP BY mail
	LIMIT 1) - 
	(SELECT SUM(durata)
	FROM utente
	JOIN Prenotazione ON Utente.mail = Prenotazione.mailUtente
	JOIN Prestazione ON Prenotazione.codice = prestazione.codicePrenotazione AND stato = 'A'
	JOIN Attività ON Prenotazione.codiceattività = Attività.codice
	WHERE Attività.tipoDisponibilità = 'O' AND NOT Attività.simmetrica
	AND Utente.mail = u.mail
	GROUP BY mail
	LIMIT 1)) saldoOre
FROM utente u;
		
-- SALDI ORE
SELECT * FROM saldi WHERE saldoOre IS NOT NULL;
	
-- SET SALDI ORE
UPDATE utente u
SET saldoOre = (
	SELECT saldoOre 
	FROM saldi 
	WHERE mail = u.mail 
	AND saldoOre IS NOT NULL
	LIMIT 1)
WHERE u.mail IN ( SELECT mail FROM saldi WHERE saldoOre IS NOT NULL);	

--ORE GUADAGNATE PER UTENTE
SELECT mail, SUM(durata)
FROM utente
JOIN Prenotazione ON Utente.mail = Prenotazione.mailUtente
JOIN Prestazione ON Prenotazione.codice = prestazione.codicePrenotazione AND stato = 'A'
JOIN Attività ON Prenotazione.codiceattività = Attività.codice
WHERE Attività.tipoDisponibilità = 'R' AND NOT Attività.simmetrica
GROUP BY mail
LIMIT 1
	
--ORE SPESE PER UTENTE
SELECT mail, SUM(durata)
FROM utente
JOIN Prenotazione ON Utente.mail = Prenotazione.mailUtente
JOIN Prestazione ON Prenotazione.codice = prestazione.codicePrenotazione AND stato = 'A'
JOIN Attività ON Prenotazione.codiceattività = Attività.codice
WHERE Attività.tipoDisponibilità = 'O' AND NOT Attività.simmetrica
GROUP BY mail

--LOOP SU CATEGORIZZAZIONI
CREATE FUNCTION foreachCategorizzazione() 
RETURNS VOID AS
$$
DECLARE
	categoria CURSOR FOR
		SELECT DISTINCT codice FROM categorizzazione;
	codiceCat INTEGER;
BEGIN
	OPEN categoria;
	FETCH categoria INTO codiceCat;
	
	WHILE FOUND LOOP
		BEGIN
			FETCH categoria INTO codiceCat;
		END;
	END LOOP;
END;
$$
LANGUAGE plpgsql;

/*

CREATE OR REPLACE TEMP VIEW valutazioniMedieSottocategoria AS
SELECT categoria, sottocategoria, AVG(voto) mediaValutazioni
FROM categorizzazione
JOIN attivita ON categorizzazione.codice = codicecategorizzazione 
JOIN prenotazione ON codiceattivita = attivita.codice
JOIN prestazione ON codiceprenotazione = prenotazione.codice
GROUP BY categoria, sottocategoria;

CREATE OR REPLACE TEMP VIEW durataPrestazioniSottocategoria AS
SELECT categoria, sottocategoria, SUM(durata) durataPrestazioni
FROM categorizzazione
JOIN attivita ON categorizzazione.codice = codicecategorizzazione
JOIN prenotazione ON codiceattivita = attivita.codice
JOIN prestazione ON codiceprenotazione = prenotazione.codice
GROUP BY categoria, sottocategoria;

CREATE OR REPLACE TEMP VIEW percentualePrestazioniSottocategoria AS
SELECT categoria, sottocategoria,
100.00 * COUNT(prestazione.codiceprenotazione) / ( CASE WHEN COUNT(prenotazione.codice) = 0 THEN 1 ELSE COUNT(prenotazione.codice) END) precentualePrenotazioni
FROM categorizzazione
LEFT JOIN attivita ON categorizzazione.codice = codicecategorizzazione
LEFT JOIN prenotazione ON attivita.codice = codiceattivita
LEFT JOIN prestazione ON prenotazione.codice = codiceprenotazione
GROUP BY categoria, sottocategoria;

*/
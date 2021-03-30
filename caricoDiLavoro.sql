SET search_path TO bancaDelTempo;

/*
1.	L’elenco delle attività offerte in una certa zona per una certa sottocategoria
2.	L’elenco degli utenti che hanno offerto prestazioni con valutazione >8 per una data categoria
3.	Selezione del numero di ore guadagnate mensilmente da un certo utente in un intervallo di tempo
4.	L’elenco delle prestazioni di attività simmetriche
5.	L’elenco degli utenti sospesi o che abbiano il saldo ore inferiore a -5
6.	L’elenco delle prenotazioni rifiutate per la giornata di oggi
*/

-- L’elenco delle attività offerte in una certa zona per una certa sottocategoria

CREATE OR REPLACE FUNCTION attivitaZonaSottocategoria(IN zonaRicerca VARCHAR(50), IN categoriaRicerca VARCHAR(50), IN sottocategoriaRicerca VARCHAR(50))
RETURNS TABLE (codice INTEGER, simmetrica BOOL, livello VARCHAR(50), specifica VARCHAR(50), tipo VARCHAR(50), tipodisponibilita CHAR(1), mailutente VARCHAR(50), codicecategorizzazione INTEGER, zona VARCHAR(50), eliminata BOOL ) 
AS $$
DECLARE
BEGIN	
	RETURN QUERY 
	SELECT attivita.*
	FROM attivita
	JOIN categorizzazione ON attivita.codiceCategorizzazione = categorizzazione.codice
	JOIN zona ON attivita.zona = denominazione AND denominazione = zonaRicerca
	WHERE categorizzazione.categoria = categoriaRicerca AND sottocategoria = sottocategoriaRicerca;
END;
$$
LANGUAGE plpgsql;

SELECT * FROM attivitaZonaSottocategoria('Genova','cat #1','red');

-- L’elenco degli utenti che hanno offerto prestazioni con valutazione >=8 per una data categoria

CREATE OR REPLACE FUNCTION utentiBenValutati(IN categoriaRicerca VARCHAR(50))
RETURNS TABLE (mail VARCHAR(50) ) 
AS $$
DECLARE
BEGIN	
	RETURN QUERY 
	SELECT DISTINCT prenotato.mail 
	FROM utente prenotato
	JOIN attivita act ON act.mailUtente = prenotato.mail
	JOIN categorizzazione ON act.codiceCategorizzazione = categorizzazione.codice
	WHERE categorizzazione.categoria = categoriaRicerca
	AND EXISTS (SELECT *
			   FROM prenotazione
			   JOIN prestazione ON prenotazione.codice = prestazione.codicePrenotazione AND voto >= 8
			   WHERE act.codice = prenotazione.codiceAttivita);
END;
$$
LANGUAGE plpgsql;

SELECT * FROM utentiBenValutati('cat #5');

-- Selezione del numero di ore guadagnate mensilmente da un certo utente in un intervallo di tempo

CREATE OR REPLACE FUNCTION oreGuadagnatePerMese(IN mailUtenteRicerca VARCHAR(50), IN da DATE, IN a DATE)
RETURNS TABLE (anno DOUBLE PRECISION, mese DOUBLE PRECISION, numeroOre NUMERIC(4,2) ) 
AS $$
DECLARE
BEGIN	
	RETURN QUERY
	SELECT EXTRACT(YEAR FROM prenotazione.data), EXTRACT(MONTH FROM prenotazione.data), SUM(durata)
	FROM prenotazione
	JOIN attivita ON codiceAttivita = attivita.codice AND attivita.mailutente = mailUtenteRicerca
	WHERE  stato = 'A' AND (NOT attivita.simmetrica) AND tipoDisponibilita = 'O'
	AND prenotazione.data BETWEEN da AND a
	GROUP BY EXTRACT(YEAR FROM prenotazione.data), EXTRACT(MONTH FROM prenotazione.data);
END;
$$
LANGUAGE plpgsql;


-- L’elenco delle prestazioni di attività simmetriche

SELECT *
FROM prestazione
JOIN prenotazione ON codiceprenotazione = prenotazione.codice
JOIN attivita ON codiceattivita = attivita.codice
WHERE simmetrica = true;

-- L’elenco degli utenti sospesi o che abbiano il saldo ore inferiore a -5

SELECT *
FROM utente
NATURAL JOIN anagrafica
WHERE sospeso OR saldoOre < -5;

-- L’elenco delle prenotazioni rifiutate per la giornata di oggi

SELECT *
FROM prenotazione 
WHERE data = current_date AND stato = 'R'

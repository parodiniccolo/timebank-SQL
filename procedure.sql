SET search_path TO bancadeltempo;

/*
	Aumento di un punto per le valutazioni di tutte le prestazioni di una certa categoria
*/

CREATE OR REPLACE FUNCTION incrementaValutazioniCategoria(IN categoriaDaIncrementare VARCHAR(50))
RETURNS VOID
AS $$
DECLARE
BEGIN	
	UPDATE prestazione SET voto = (
		CASE WHEN voto = 10 
		THEN voto 
		ELSE voto + 1 END)
	WHERE codicePrenotazione IN 
		(SELECT prenotazione.codice
		FROM prenotazione 
		JOIN attivita ON codiceattivita = attivita.codice
		JOIN categorizzazione ON codicecategorizzazione = categorizzazione.codice
		WHERE categoria = categoriaDaIncrementare);
END;
$$
LANGUAGE plpgsql;

/*
	Utenti con valutazione media superiore ad una valutazione arbitraria
*/

CREATE OR REPLACE FUNCTION incrementaValutazioniCategoria(IN categoriaDaIncrementare VARCHAR(50))
RETURNS VOID
AS $$
DECLARE
BEGIN	
	UPDATE prestazione SET voto = (
		CASE WHEN voto = 10 
		THEN voto 
		ELSE voto + 1 END)
	WHERE codicePrenotazione IN 
		(SELECT prenotazione.codice
		FROM prenotazione 
		JOIN attivita ON codiceattivita = attivita.codice
		JOIN categorizzazione ON codicecategorizzazione = categorizzazione.codice
		WHERE categoria = categoriaDaIncrementare);
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION utentiValutazioneSuperiore(IN soglia NUMERIC(4,2))
RETURNS TABLE (mail VARCHAR(50) ) 
AS $$
DECLARE
BEGIN	
	 RETURN QUERY
	 	SELECT informazioniUtente.mail FROM informazioniUtente WHERE mediaValutazioni > soglia;
END;
$$
LANGUAGE plpgsql;

/*
	Set del saldo ore a -5 per tutti gli utenti con saldoore inferiore a -5
*/	

CREATE FUNCTION bonusOre() 
RETURNS VOID AS
$$
DECLARE
	cursorUtente CURSOR FOR
		SELECT DISTINCT mail FROM utente;
	mailUtente VARCHAR(50);
BEGIN
	OPEN cursorUtente;
	FETCH cursorUtente INTO mailUtente;
	
	WHILE FOUND LOOP
		BEGIN
			IF (SELECT saldoOre FROM utente WHERE mail = mailUtente) < -5
			THEN
				UPDATE utente SET saldoOre = -5 WHERE mail = mailUtente;
			END IF;
			FETCH cursorUtente INTO mailUtente;
		END;
	END LOOP;
END;
$$
LANGUAGE plpgsql;

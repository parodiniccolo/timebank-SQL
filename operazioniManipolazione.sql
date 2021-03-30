SET search_path TO bancadeltempo;

/*
	La definizione di una vista che fornisca alcune informazioni riassuntive ogni utente, il saldo ore, la valutazione media ottenuta; 
*/

CREATE VIEW informazioniUtente AS
	(SELECT utente.mail, nome, cognome, saldoOre, AVG(voto) mediaValutazioni
	FROM utente
	NATURAL JOIN anagrafica
	JOIN attivita ON utente.mail = attivita.mailutente
	JOIN prenotazione ON attivita.codice = codiceattivita
	JOIN prestazione ON prenotazione.codice = codiceprenotazione
	GROUP BY utente.mail, nome, cognome, saldoOre); 
	
SELECT * FROM informazioniUtente	

/*
 	Determinare gli utenti che non hanno né erogato né usufruito di attività in una certa categoria
	(interrogazione di differenza & sotto-interrogazione)
*/

CREATE OR REPLACE FUNCTION utentiEsclusiDaCategoria(IN categoriaRicerca VARCHAR(50))
RETURNS TABLE (mail VARCHAR(50) ) 
AS $$
DECLARE
BEGIN	
	CREATE OR REPLACE TEMP VIEW attivitaCategoria AS
	SELECT categorizzazione.categoria AS categoria, attivita.mailUtente AS prenotato, prenotazione.mailUtente AS prenotante
	FROM Prestazione
	JOIN Prenotazione ON codiceprenotazione = prenotazione.codice
	JOIN Attivita ON codiceattivita = attivita.codice
	JOIN Categorizzazione ON codicecategorizzazione = categorizzazione.codice;

	RETURN QUERY 
	SELECT utente.mail
	FROM utente
	EXCEPT (
		(SELECT prenotato FROM attivitaCategoria WHERE categoria = categoriaRicerca) 
		UNION 
		(SELECT prenotante FROM attivitaCategoria WHERE categoria = categoriaRicerca));
END;
$$
LANGUAGE plpgsql;

/*
	determinare per ogni attività, l’elenco degli utenti che la erogano e degli utenti che ne hanno usufruito, 
	con relative zone di riferimento e valutazioni medie ricevute/fornite
	(interrogazione con outer join)
*/

SELECT categoria, sottocategoria, prenotante.mail usufruente, prenotante.mediavalutazioni, prenotato.mail erogante, prenotato.mediavalutazioni, attivita.zona
FROM categorizzazione
LEFT JOIN attivita  ON codicecategorizzazione = categorizzazione.codice
LEFT JOIN informazioniUtente prenotato ON attivita.mailUtente = prenotato.mail
LEFT JOIN prenotazione ON attivita.codice = codiceattivita 
LEFT JOIN informazioniUtente prenotante ON prenotazione.mailutente = prenotante.mail
ORDER BY categorizzazione.codice;

/*
	determinare gli utenti che offrono attività di una certa sottocategoria in una certa zona, 
	con valutazione superiore alla media delle valutazioni degli utenti per le attività di quella sottocategoria
	(intterogazione con sotto-interrogazione)
*/

CREATE OR REPLACE FUNCTION utentiValutatiSopraMediaSottocategoria(IN categoriaRicerca VARCHAR(50), sottocategoriaRicerca VARCHAR(50), zonaRicerca VARCHAR(50))
RETURNS TABLE (mail VARCHAR(50) ) 
AS $$
DECLARE
BEGIN	

	RETURN QUERY 
	SELECT informazioniUtente.mail 
	FROM categorizzazione cat
	JOIN attivita act ON cat.codice = act.codicecategorizzazione AND  categoria = categoriaRicerca AND sottocategoria = sottocategoriaRicerca
	JOIN informazioniUtente ON informazioniUtente.mail = act.mailutente
	JOIN valutazionimediesottocategoria ON subcat = cat.codice
	WHERE  zona = zonaRicerca
	AND mediaValutazioni > ALL (SELECT AVG(voto)
							FROM attivita
							JOIN prenotazione ON codiceattivita = act.codice
							JOIN prestazione ON codiceprenotazione = prenotazione.codice
							GROUP BY codicecategorizzazione);
							
END;
$$
LANGUAGE plpgsql;

/*
	per ogni categoria, determinare la sottocategoria di quella categoria che la più alta percentuale di prenotazioni che si traducono in prestazioni, 
	con il corrispondente numero di ore di prestazioni effettuate e la relativa valutazione media
	(interrogazione con raggruppamento e funzioni di gruppo)
*/

CREATE OR REPLACE TEMP VIEW categorieconDettagli AS
select categoria.categoria, c.sottocategoria, 
	SUM(durata) durataPrestazioni, 
	AVG(voto) valutazioneMedia, 
	100.00 * COUNT(prestazione.codiceprenotazione) / ( CASE WHEN COUNT(prenotazione.codice) = 0 THEN 1 ELSE COUNT(prenotazione.codice) END) percentualePrestazioni
from categoria
LEFT JOIN categorizzazione c ON categoria.categoria = c.categoria
LEFT JOIN attivita ON c.codice = codicecategorizzazione
LEFT JOIN prenotazione ON attivita.codice = codiceattivita
LEFT JOIN prestazione ON prenotazione.codice = codiceprenotazione
GROUP BY categoria.categoria, c.sottocategoria

select cd.*
from categoria c
left join categorieconDettagli cd ON c.categoria = cd.categoria
where cd.percentualePrestazioni >= ALL (select percentualePrestazioni from categorieconDettagli where categorieconDettagli.categoria = c.categoria)
ORDER BY c.categoria

/*
	determinare gli utenti che hanno usufruito o fornito attività di tutte le categorie
	(operazione di divisione)
*/

CREATE OR REPLACE TEMP VIEW utentiCategorieLegate AS
SELECT DISTINCT utente.mail mailUtente, categotia.categoria
FROM utente 
LEFT JOIN attivita a1 ON utente.mail = a1 .mailUtente
LEFT JOIN prenotazione ON utente.mail = prenotazione.mailUtente AND prenotazione.stato = 'A'
LEFT JOIN attivita a2 ON codiceattivita = a2.codice
LEFT JOIN categorizzazione  ON a1.codicecategorizzazione = categorizzazione.codice OR a2.codicecategorizzazione = categorizzazione.codice
ORDER BY utente.mail

SELECT u.mail
FROM utente u
JOIN utentiCategorieLegate ON mailUtente = u.mail
GROUP BY u.mail HAVING count(utentiCategorieLegate.mailUtente) = (SELECT count(*) FROM categoria);

/*
	inserimento di una nuova sottocategoria
	(operazione di inserimento)
*/

CREATE OR REPLACE FUNCTION insertSottocategoria(IN cat VARCHAR(50), IN nuovaSottocategoria VARCHAR(50))
RETURNS VOID
AS $$
DECLARE
BEGIN	
	INSERT INTO Categorizzazione VALUES(DEFAULT,cat,nuovaSottocategoria);							
END;
$$
LANGUAGE plpgsql;

/*
	modifica di una prenotazione (non può essere accetata)
	(operazione di modifica)
*/

CREATE OR REPLACE FUNCTION updatePrenotazione(IN cod INTEGER, IN newData DATE, IN newOra TIME, IN newLuogo VARCHAR(50), IN newDurata NUMERIC(4,2), IN newAnnotazioni VARCHAR(500))
RETURNS VOID
AS $$
DECLARE
BEGIN	
	UPDATE prenotazione SET data = newData, ora = newOra, luogo = newLuogo, durata = newDurata, annotazioni = newAnnotazioni
	WHERE codice = cod;
END;
$$
LANGUAGE plpgsql;

/*
	cancellazione di un numero di telefono
	(operazione di cancellazione)
*/

CREATE OR REPLACE FUNCTION deleteTelefono(IN numeroDaEliminare VARCHAR(50), IN mailUtente VARCHAR(50))
RETURNS VOID
AS $$
DECLARE
BEGIN	
	DELETE FROM telefono WHERE numero = numeroDaEliminare AND mail = mailUtente;  
END;
$$
LANGUAGE plpgsql;


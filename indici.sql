SET search_path TO bancaDelTempo;

CREATE INDEX index_saldoOre 
ON utente (saldoOre);

CREATE INDEX index_sottocategoria 
ON categorizzazione
USING HASH (sottocategoria);

CREATE INDEX index_voto 
ON prestazione (voto);

CREATE INDEX index_stato
ON prenotazione 
USING hash (stato);

CREATE INDEX index_mailUtentePrenotazione
ON prenotazione
USING hash (mailUtente);

CREATE INDEX index_mailutenteAttivita
ON attivita 
USING HASH (mailUtente);


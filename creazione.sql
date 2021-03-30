CREATE SCHEMA bancaDelTempo;

SET search_path TO bancaDelTempo;

analyze;

SELECT relname, relfilenode, relpages, reltuples
FROM pg_class
JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.oid
WHERE pg_namespace.nspname = 'bancadeltempo';

/* #tuple: 800, #pagine: 7 */

CREATE TABLE Utente (
	mail VARCHAR(50) PRIMARY KEY,
	sospeso BOOL NOT NULL DEFAULT false,
	saldoOre NUMERIC(6,2) NOT NULL DEFAULT 0
);

/* #tuple: 800, #pagine: 11 */

CREATE TABLE Anagrafica (
	mail VARCHAR(50) PRIMARY KEY REFERENCES UTENTE 
		ON UPDATE CASCADE 
		ON DELETE CASCADE
		CHECK(mail ~ '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$'),
	nome VARCHAR(50) NOT NULL,
	cognome VARCHAR(50) NOT NULL,
	genere CHAR(1) NOT NULL CHECK (genere = 'F' OR genere = 'M' OR genere = 'A'),
	datanascita DATE NOT NULL,
	luogonascita VARCHAR(50) NOT NULL,
	indirizzo VARCHAR(50) NOT NULL
);

/* #tuple: 1157, #pagine: 11 */

CREATE TABLE Telefono (
	numero VARCHAR(50),
	mail VARCHAR(50) REFERENCES Utente 
		ON UPDATE CASCADE 
		ON DELETE CASCADE,  
	PRIMARY KEY (numero, mail)
);

/* #tuple: 20, #pagine: 1 */

CREATE TABLE Zona (
	denominazione VARCHAR(50) PRIMARY KEY
);

/* #tuple: 50, #pagine: 1 */

CREATE TABLE Categoria (
	categoria VARCHAR(50) PRIMARY KEY
);

/* #tuple: 1250, #pagine: 8 */

CREATE TABLE Categorizzazione (
	codice SERIAL PRIMARY KEY,
	categoria VARCHAR(50) NOT NULL REFERENCES Categoria 
		ON UPDATE CASCADE 
		ON DELETE CASCADE,
	sottocategoria VARCHAR(50) NOT NULL,
	UNIQUE (categoria, sottocategoria)
);

/* #tuple: 7218, #pagine: 83 */

CREATE TABLE Attivita (
	codice SERIAL PRIMARY KEY,
	simmetrica BOOLEAN NOT NULL,
	livello VARCHAR(50),
	specifica VARCHAR(50),
	tipo VARCHAR(50),
	tipoDisponibilita CHAR(1) NOT NULL CHECK (tipoDisponibilita = 'R' OR tipoDisponibilita = 'O'),
	mailUtente VARCHAR(50) NOT NULL REFERENCES Utente
		ON UPDATE CASCADE
		ON DELETE NO ACTION,
	codiceCategorizzazione INTEGER NOT NULL REFERENCES Categorizzazione
		ON UPDATE CASCADE
		ON DELETE NO ACTION,
	zona VARCHAR(50) NOT NULL REFERENCES Zona
		ON UPDATE CASCADE
		ON DELETE NO ACTION,
	eliminata BOOLEAN NOT NULL DEFAULT false
);

/* #tuple: 11049, #pagine: 212 */

CREATE TABLE Prenotazione (
	codice SERIAL PRIMARY KEY,
	data DATE NOT NULL,
	ora TIME NOT NULL,
	luogo VARCHAR(50) NOT NULL,
	durata NUMERIC(4,2) NOT NULL CHECK (durata % 0.25 = 0),
	annotazioni VARCHAR(500),
	stato CHAR(1) NOT NULL DEFAULT 'S' CHECK (stato = 'S' OR stato = 'A' OR stato = 'R'),
	mailUtente VARCHAR(50) NOT NULL REFERENCES Utente
		ON UPDATE CASCADE
		ON DELETE NO ACTION,
	codiceAttivita INTEGER NOT NULL REFERENCES Attivita
		ON UPDATE CASCADE
		ON DELETE NO ACTION
);

/* #tuple: 8241, #pagine: 118 */

CREATE TABLE Prestazione (
	codicePrenotazione INTEGER PRIMARY KEY REFERENCES Prenotazione
		ON UPDATE CASCADE
		ON DELETE RESTRICT,
	voto NUMERIC(2) NOT NULL CHECK (voto BETWEEN 1 AND 10),
	feedback VARCHAR(500)
);
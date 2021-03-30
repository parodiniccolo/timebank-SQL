SET search_path TO bancadeltempo;

CREATE ROLE Utente;
CREATE ROLE Correntista;
CREATE ROLE ResponsabileCat;
CREATE ROLE AmministratoreBanca;

GRANT Utente TO Correntista;
GRANT Correntista TO ResponsabileCat;
GRANT ResponsabileCat TO AmministratoreBanca WITH ADMIN OPTION;

GRANT USAGE ON SCHEMA bancaDelTempo TO Utente;

GRANT SELECT 
ON Categoria, Categorizzazione, Attivita, Zona
TO Utente;

GRANT SELECT (Voto, Feedback)
ON Prestazione
TO Utente;

GRANT SELECT, INSERT, UPDATE (mail, sospeso)
ON Utente
TO Correntista;

GRANT SELECT, INSERT, UPDATE
ON Anagrafica
TO Correntista;

GRANT ALL 
ON Telefono, Attivita, Prenotazione, Prestazione
To Correntista;

GRANT ALL
ON Categoria, Categorizzazione
TO ResponsabileCat
WITH GRANT OPTION;

GRANT ALL PRIVILEGES
ON  ALL TABLES IN SCHEMA bancaDelTempo
TO AmministratoreBanca
WITH GRANT OPTION;

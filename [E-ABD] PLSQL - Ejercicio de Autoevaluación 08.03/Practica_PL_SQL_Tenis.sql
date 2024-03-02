/*
    Aplicaciones de Bases de Datos.
    Ingeniería Informática. UBU. Curso 23-24
    Fernando Pisot Serrano fps1001@alu.ubu.es
    
    [E-ABD] PLSQL - Ejercicio de Autoevaluación 08.03

    Respuestas a las preguntas:
        -- 1. - Trunca las fechas para comparar solo los días.

        -- 2. sql%rowcount devuelve el número de filas que han sido afectadas.
        En este caso si ha sido afectada una fila significa que se ha borrado con éxito la reserva.
        porque ha encontrado un registro coincidente con los parámetros de la función.
        Si no ha encontrado ninguna fila afectada es porque no hay reserva con los datos dados.

        -- 3. Una variable de tipo cursor es un puntero que permite navegar por los registros.
        En reservarPista la variable vPistasLibres es un cursor que apunta a posiciones de reserva libres.
        *Ver comentarios en código de OPEN, FETCH, CLOSE y FOUND/NOTFOUND*

*/



drop table reservas;
drop table pistas;
drop sequence seq_pistas;

create table pistas (
	nro integer primary key
	);
	
create table reservas (
	pista integer references pistas(nro),
	fecha date,
	hora integer check (hora >= 0 and hora <= 23),
	socio varchar(20),
	primary key (pista, fecha, hora)
	);
	
create sequence seq_pistas;

insert into pistas values (seq_pistas.nextval);
insert into reservas 
	values (seq_pistas.currval, '20/03/2018', 14, 'Pepito');
insert into pistas values (seq_pistas.nextval);
insert into reservas 
	values (seq_pistas.currval, '24/03/2018', 18, 'Pepito');
insert into reservas 
	values (seq_pistas.currval, '21/03/2018', 14, 'Juan');
insert into pistas values (seq_pistas.nextval);
insert into reservas 
	values (seq_pistas.currval, '22/03/2018', 13, 'Lola');
insert into reservas 
	values (seq_pistas.currval, '22/03/2018', 12, 'Pepito');

commit;

create or replace function anularReserva( 
	p_socio varchar,
	p_fecha date,
	p_hora integer, 
	p_pista integer ) 
return integer is

begin
	DELETE FROM reservas 
        WHERE
            -- 1. - Trunca las fechas para comparar solo los días
            trunc(fecha) = trunc(p_fecha) AND
            pista = p_pista AND
            hora = p_hora AND
            socio = p_socio;
    /*
    2. - sql%rowcount devuelve el número de filas que han sido afectadas.
    En este caso si ha sido afectada una fila significa que se ha borrado con éxito la reserva.
    porque ha encontrado un registro coincidente con los parámetros de la función.
    Si no ha encontrado ninguna fila afectada es porque no hay reserva con los datos dados.
    */
	if sql%rowcount = 1 then
		commit;
		return 1;
	else
		rollback;
		return 0;
	end if;
end;
/

create or replace FUNCTION reservarPista(
        p_socio VARCHAR,
        p_fecha DATE,
        p_hora INTEGER
    ) 
RETURN INTEGER IS

    CURSOR vPistasLibres IS
        SELECT nro
        FROM pistas 
        WHERE nro NOT IN (
            SELECT pista
            FROM reservas
            WHERE
                 
                trunc(fecha) = trunc(p_fecha) AND
                hora = p_hora)
        order by nro;
            
    vPista INTEGER;

BEGIN
    OPEN vPistasLibres; -- Ejecuta la consulta de arriba.
    FETCH vPistasLibres INTO vPista; -- Recupera la siguiente fila del resultado de la consulta.

    IF vPistasLibres%NOTFOUND -- Si el valor del cursor es NOTFOUND es TRUE es que no hay pistas libres.
                              -- %FOUND devolvería TRUE si recuperó alguna fila.
    THEN
        CLOSE vPistasLibres; -- Libera los recursos.
        RETURN 0; -- reservarPista devuelve 0 (sin éxito)
    END IF;

    INSERT INTO reservas VALUES (vPista, p_fecha, p_hora, p_socio); -- Si llega hasta aquí es que hay registros con pistas libres
    CLOSE vPistasLibres;
    COMMIT;
    RETURN 1;
END;
/

/*
SET SERVEROUTPUT ON
declare
 resultado integer;
begin
 
     resultado := reservarPista( 'Socio 1', CURRENT_DATE, 12 );
     if resultado=1 then
        dbms_output.put_line('Reserva 1: OK');
     else
        dbms_output.put_line('Reserva 1: MAL');
     end if;
     
     --Continua tu solo....
     
      
    resultado := anularreserva( 'Socio 1', CURRENT_DATE, 12, 1);
     if resultado=1 then
        dbms_output.put_line('Reserva 1 anulada: OK');
     else
        dbms_output.put_line('Reserva 1 anulada: MAL');
     end if;
  
     resultado := anularreserva( 'Socio 1', date '1920-1-1', 12, 1);
     --Continua tu solo....
  
end;
/
*/


/*
    Aplicaciones de Bases de Datos.
    Ingeniería Informática. UBU. Curso 23-24
    Fernando Pisot Serrano fps1001@alu.ubu.es
    Repositorio github: https://github.com/fps1001/ABD 
    
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

        -- 4. Semanticamnete no daría lo mismo sustituir en anularReserva el commit y el rollback.
        El commit confirmaría el borrado de la reserva al encontrar un registro coincidente que si fuera un rollback no se haría. (error)
        El rollback se llevaría a cabo si no hubiera registros afectados en cuyo casi si daría igual hacer un commit pero no tendría el mismo significado semántico,
        pues la función devuelve 1 o 0 en función del éxito de la misma. Al hacer commit estamos suponiendo un éxito de la misma.

        -- 5. La función reservarPista puede sufrir excepciones o errores que no están siendo capturados y dejar la transición abierta.
        Para solucionarlo habría que manejar las excepciones, se realizan cambios a continuación en la función.

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

-- 5. Si se produce excepción durante la función se ejecuta este código para no dejar transiciones abiertas.
EXCEPTION
    WHEN OTHERS THEN -- Cualquier tipo de excepción se pone OTHERS en los apuntes.
        IF vPistasLibres%ISOPEN THEN -- Cierra el cursor
            CLOSE vPistasLibres;
        END IF;
        ROLLBACK; -- Revierte cambios
        RETURN 0; -- Devuelve fallo
    
END;
/
/*
-- Paso 2. Bloque anonimo
BEGIN
    -- 2.1 Tres reservas válidas.
    dbms_output.put_line('Intento 1, Socio 1: ' || reservarPista('Socio 1', CURRENT_DATE, 12));
    dbms_output.put_line('Intento 2, Socio 2: ' || reservarPista('Socio 2', CURRENT_DATE, 12));
    dbms_output.put_line('Intento 3, Socio 3: ' || reservarPista('Socio 3', CURRENT_DATE, 12));
    
    -- 2.2 Intento de una cuarta reserva, que debería fallar.
    dbms_output.put_line('Intento 4, Socio 4 (debería fallar): ' || reservarPista('Socio 4', CURRENT_DATE, 12));
    
    -- 2.3 Anula una reserva válida.
    dbms_output.put_line('Anulación 1, Socio 1: ' || anularReserva('Socio 1', CURRENT_DATE, 12, 1));
    
    -- 2.4 Borrado de reserva inexistente
    dbms_output.put_line('Anulación 2, Socio 1 en fecha inexistente: ' || anularReserva('Socio 1', DATE '1920-1-1', 12, 1));

    -- 2.2 Select para confirmar que ha funcionado todo:
    dbms_output.put_line('Estado final de las reservas:');
    FOR r IN (SELECT pista, fecha, hora, socio FROM reservas ORDER BY pista, fecha, hora) LOOP
        dbms_output.put_line('Pista: ' || r.pista || ', Fecha: ' || r.fecha || ', Hora: ' || r.hora || ', Socio: ' || r.socio);
    END LOOP;

END;
/
*/

-- Paso 3: Script para ejecutar que da privilegios al usuario hr para poder usar el debugger:
GRANT DEBUG CONNECT SESSION TO hr;
GRANT DEBUG ANY PROCEDURE TO hr;
GRANT SELECT ANY DICTIONARY TO hr;
-- Da error si no se conecta como SYSDBA a la base de datos por falta de privilegios.
-- Creo el acceso con sys/1234 que no había hecho con rol SYSDBA y ejecuto marcandome: Grnt correcto.
-- Ejecuto con el debuuger la función sin problemas realizando una reserva que vuelvo a borrar.


-- Paso 4: mismo código pero dentro de función
CREATE OR REPLACE PROCEDURE TEST_FUNCIONES_TENIS IS
BEGIN
    -- Realizar tres reservas válidas.
    dbms_output.put_line('Intento 1, Socio 1: ' || reservarPista('Socio 1', CURRENT_DATE, 12));
    dbms_output.put_line('Intento 2, Socio 2: ' || reservarPista('Socio 2', CURRENT_DATE, 12));
    dbms_output.put_line('Intento 3, Socio 3: ' || reservarPista('Socio 3', CURRENT_DATE, 12));
    
    -- Intento de una cuarta reserva, que debería fallar.
    dbms_output.put_line('Intento 4, Socio 4 (debería fallar): ' || reservarPista('Socio 4', CURRENT_DATE, 12));
    
    -- Anular una reserva válida.
    dbms_output.put_line('Anulación 1, Socio 1: ' || anularReserva('Socio 1', CURRENT_DATE, 12, 1));
    
    -- Intento de anular una reserva inexistente.
    dbms_output.put_line('Anulación 2, Socio 1 en fecha inexistente: ' || anularReserva('Socio 1', DATE '1920-1-1', 12, 1));
    
    -- Mostrar el estado final de las reservas.
    dbms_output.put_line('Estado final de las reservas:');
    FOR r IN (SELECT pista, fecha, hora, socio FROM reservas ORDER BY pista, fecha, hora) LOOP
        dbms_output.put_line('Pista: ' || r.pista || ', Fecha: ' || TO_CHAR(r.fecha, 'DD/MM/YYYY') || ', Hora: ' || r.hora || ', Socio: ' || r.socio);
    END LOOP;
END;
/

-- Bloque anónimo llamando a función.
BEGIN
    TEST_FUNCIONES_TENIS;
END;
/
-- Llamada con execute
-- EXEC TEST_FUNCIONES_TENIS;






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


/*
-- SALIDA DE SCRIPT AL EJECUTAR EL SCRIPT



Table PISTAS creado.


Table RESERVAS creado.


Sequence SEQ_PISTAS creado.


1 fila insertadas.


1 fila insertadas.


1 fila insertadas.


1 fila insertadas.


1 fila insertadas.


1 fila insertadas.


1 fila insertadas.


1 fila insertadas.

Confirmación terminada.

Function ANULARRESERVA compilado


Function RESERVARPISTA compilado


Procedure TEST_FUNCIONES_TENIS compilado

Procedimiento PL/SQL terminado correctamente.


*/
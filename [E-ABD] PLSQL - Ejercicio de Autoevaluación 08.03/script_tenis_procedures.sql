/*
    Aplicaciones de Bases de Datos.
    Ingeniería Informática. UBU. Curso 23-24
    Fernando Pisot Serrano fps1001@alu.ubu.es
    Repositorio github: https://github.com/fps1001/ABD 
    
    [E-ABD] PLSQL - Ejercicio de Autoevaluación 08.03

    Paso 5: convertir funciones en procedimientos: cambiando function por procedure y como no puede devolver valores igual se usa raise_application_error
    en los casos en que la reserva por ejemplo no exista o que no haya pistas libres disponibles.

*/

-- Creamos procedures pRservarPista y pAnularReserva
CREATE OR REPLACE PROCEDURE pAnularReserva( 
    p_socio VARCHAR,
    p_fecha DATE,
    p_hora INTEGER, 
    p_pista INTEGER ) 
IS
BEGIN
    DELETE FROM reservas 
    WHERE
        trunc(fecha) = trunc(p_fecha) AND
        pista = p_pista AND
        hora = p_hora AND
        socio = p_socio;

    IF sql%rowcount = 0 THEN
        raise_application_error(-20000, 'Reserva inexistente'); -- generamos la excepción que indica el guión si no hay reserva, sino acabamos.
    END IF;

    COMMIT;
END;
/

CREATE OR REPLACE PROCEDURE pReservarPista(
    p_socio VARCHAR,
    p_fecha DATE,
    p_hora INTEGER
) IS
    vPista INTEGER;
    CURSOR vPistasLibres IS
        SELECT nro
        FROM pistas 
        WHERE nro NOT IN (
            SELECT pista
            FROM reservas
            WHERE trunc(fecha) = trunc(p_fecha) AND hora = p_hora)
        ORDER BY nro;
BEGIN
    OPEN vPistasLibres;
    FETCH vPistasLibres INTO vPista;

    IF vPistasLibres%NOTFOUND THEN
        CLOSE vPistasLibres;
        raise_application_error(-20001, 'No quedan pistas libres en esa fecha y hora');  -- generamos una excepción si no hay pistas libres, sino reservamos.
    ELSE
        INSERT INTO reservas VALUES (vPista, p_fecha, p_hora, p_socio);
        CLOSE vPistasLibres;
        COMMIT;
    END IF;
EXCEPTION -- Para el resto de excepciones, cerramos y hacemos rollback a los cambios.
    WHEN OTHERS THEN
        IF vPistasLibres%ISOPEN THEN
            CLOSE vPistasLibres;
        END IF;
        ROLLBACK;
        RAISE;
END;
/

-- Creamos test_procedures_tenis que usará las procedures anteriores. Se ajusta el código para manejar excepciones
-- Copio el de funciones, cambio a procedure y hago el manejo de excepciones.

CREATE OR REPLACE PROCEDURE TEST_PROCEDURES_TENIS IS
BEGIN
    -- Realizar tres reservas válidas.
    pReservarPista('Socio 1', CURRENT_DATE, 12);
    dbms_output.put_line('Reserva 1, Socio 1: OK');
    
    pReservarPista('Socio 2', CURRENT_DATE, 12);
    dbms_output.put_line('Reserva 2, Socio 2: OK');
    
    pReservarPista('Socio 3', CURRENT_DATE, 12);
    dbms_output.put_line('Reserva 3, Socio 3: OK');
    
    -- Intento de una cuarta reserva, que debería fallar.
    BEGIN
        pReservarPista('Socio 4', CURRENT_DATE, 12);
    EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line('Intento 4, Socio 4 (debería fallar): OK');
    END;
    
    -- Anular una reserva válida.
    pAnularReserva('Socio 1', CURRENT_DATE, 12, 1);
    dbms_output.put_line('Anulación 1, Socio 1: OK');
    
    -- Intento de anular una reserva inexistente.
    BEGIN
        pAnularReserva('Socio 1', DATE '1920-1-1', 12, 1);
    EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line('Anulación 2, Socio 1 en fecha inexistente: OK');
    END;

    -- Imprimo el estado final de todas las reservas.
    dbms_output.put_line('Estado final de las reservas:');
    FOR r IN (SELECT pista, fecha, hora, socio FROM reservas ORDER BY pista, fecha, hora) LOOP
        dbms_output.put_line('Pista: ' || r.pista || ', Fecha: ' || TO_CHAR(r.fecha, 'DD/MM/YYYY') || ', Hora: ' || r.hora || ', Socio: ' || r.socio);
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN
        dbms_output.put_line(SQLERRM);
        ROLLBACK;
END;
/


/* Paso 6: si 2 transacciones ReservarPista se solapan en el tiempo queriendo ambas reservar la última pista que queda libre en una 
determinada fecha y hora y si sugieres algún arreglo al respecto

Sólo una de las dos reservas concurrentes tendrá éxito mientras que la otra dará error.
Habría que implementar un control de concurrencia para solucionarlo. Los apuntes mencionan un bloqueo implícito con SELECT FOR UPDATE pero no veo como aplicarlo al contexto.
Sería suficiente con mantener un nivel de aislamiento a nivel de sesión que garantice un control de concurrencia.
Por ejemplo si pusieramos:
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
lo que garantizaría que la sesión antes de ejecutarse el procemiento tendría un nivel de aislamiento serializable.
Aunque esta solución no se puede aplicar al procedimiento almacenado.
También se podría hacer con reintentos controlados pero en el caso que nos ocupa darían fallo salvo que volviera a quedar libre la reserva.


*/

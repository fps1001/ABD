/*
Aplicaciones de Bases de Datos.
Ingeniería Informática. UBU. Curso 23-24
Fernando Pisot Serrano fps1001@alu.ubu.es
Repositorio github: https://github.com/fps1001/ABD 

[E-ABD] PL/SQL - Ejercicio de Evaluación 1 (7.5%) - 03/04
-- Además de hacer la práctica intenté lo siguiente:
- Esta vez voy a intentar realizar la práctica desde visual studio con la extensión: 
Oracle Developer Tools for VS Code (SQL and PLSQL) 
Y la instalación de 
Oracle Instant Client Downloads for Microsoft Windows (x64) 64-bit
- Después probé con docker sin éxito.
- 22.03.24: Probé con livesql.oracle.com me parece un poco mejor que sqldeveloper: sobretodo la salida de compilador.
- 25.03.24: Una vez solucionado el segundo método: tuve problemas con el %like% de los apuntes pues busca el error exacto, en vez de contenerlo.
y el fallo contenido debía ser en mayusculas, empezó a funcionar. Revisé y subí el contenido.

*/

-- Elimina la tabla 'asignaturas' si existe, incluyendo todas sus restricciones de integridad.
BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE asignaturas CASCADE CONSTRAINTS';
EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE = -942 THEN -- ORA-00942: si la tabla no existe
         NULL; -- No hace nada
      ELSE
         RAISE; -- Re-lanza cualquier otra excepción que no sea la de tabla inexistente.
      END IF;
END;
/

-- Creación de la tabla 'asignaturas' con sus respectivos campos y restricciones.
-- Campos: idAsignatura (identificador de la asignatura), nombre, titulación a la que pertenece, y número de créditos.
-- Restricciones: Una clave primaria compuesta por 'idAsignatura' y 'titulacion', y una restricción de unicidad para la combinación de 'nombre' y 'titulacion'.
create table asignaturas(
  idAsignatura  integer,
  nombre        varchar(20) not null,
  titulacion    varchar(20),
  ncreditos     integer,
  -- Damos nombre a las restricciones que usaremos en el segundo método:
  constraint PK_Asignaturas primary key ( idAsignatura, titulacion ),
  constraint UNQ_Asignaturas unique (nombre, titulacion) 
);

-- 1. MÉTODO CON SELECTS ---------------------------------------------------------------------------------
-- Realizaré el test después de cada método así testeamos los dos.
create or replace procedure insertaAsignatura(
  v_idAsignatura integer, v_nombreAsig varchar, v_titulacion varchar, v_ncreditos integer) 
    IS
    v_existente_nombre VARCHAR(200);
BEGIN
  INSERT INTO asignaturas VALUES (
    v_idAsignatura, v_nombreAsig, v_titulacion, v_ncreditos);
EXCEPTION
  
    -- La siguiente select solo se realiza en caso de error mejorando la eficiencia.
    -- Se elemina SELECT COUNT desaconsejada en los apuntes (pg8).
    -- SELECT COUNT(*) INTO v_count FROM asignaturas -- Realizamos una select que devolverá el número de registros que coinciden
    WHEN DUP_VAL_ON_INDEX THEN -- En cambio uso DUP_VAL_ON_INDEX usado en apuntes p22 y p23
        BEGIN
            -- Intentamos bloquear la fila específica para ver si el error es por idAsignatura
            SELECT nombre INTO v_existente_nombre 
            FROM asignaturas 
            WHERE idAsignatura = v_idAsignatura 
            AND titulacion = v_titulacion 
            FOR UPDATE;
            
            -- Si llegamos a este punto, el fallo es por idAsignatura duplicado porque existe un valor y no se ha generado error hasta aquí.
            RAISE_APPLICATION_ERROR(-20000, 'La asignatura con idAsignatura=' || v_idAsignatura || 
                ' está repetida en la titulación ' || v_titulacion || '.');
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- Si se lanza la excepción es porque no encontramos la fila, entonces el fallo es por nombre repetido
                RAISE_APPLICATION_ERROR(-20001, 'La asignatura con nombre=' || v_nombreAsig || 
                    ' está repetida en la titulación ' || v_titulacion || '.');
        END;
    WHEN OTHERS THEN
        RAISE; -- En otros casos lanzamos la excepción
END insertaAsignatura;

/

--juego de pruebas automáticas
create or replace procedure test_asignaturas is
  begin
      begin --bloque comun de inicializaciones
        delete from asignaturas;
        insert into asignaturas values ( 1, 'ALGEBRA', 'GRADO INFORMATICA', 6);
        insert into asignaturas values ( 1, 'ALGEBRA', 'GRADO MECANICA', 6);
        commit;
      end;
      
      begin
        insertaAsignatura ( 2, 'ALGEBRA', 'GRADO INFORMATICA', 6);
        dbms_output.put_line('Mal: No detecta error combinacion nombre asignatura + titulación repetida');
      exception
        when others then
          if sqlcode=-20001 then
            dbms_output.put_line('Bien: si detecta error combinacion nombre asignatura + titulación repetida');
            dbms_output.put_line(SQLERRM);
            dbms_output.put_line('');
          else
            dbms_output.put_line('Mal: No detecta error combinacion nombre asignatura + titulación repetida');
            dbms_output.put_line('error='||SQLCODE||'=>'||SQLERRM);
          end if;
      end;
      
      begin
        insertaAsignatura ( 1, 'PROGRAMACION', 'GRADO INFORMATICA', 6);
        dbms_output.put_line('Mal: No detecta error combinacion id asignatura + titulación repetida');
      exception
        when others then
           if sqlcode=-20000 then
            dbms_output.put_line('Bien: si detecta error combinacion id asignatura + titulación repetida');
            dbms_output.put_line(SQLERRM);
            dbms_output.put_line('');
          else
            dbms_output.put_line('Mal: No detecta error combinacion id asignatura + titulación repetida');
            dbms_output.put_line('error='||SQLCODE||'=>'||SQLERRM);
          end if;
      end;
      
      declare
        v_valorEsperado varchar(100):='1ALGEBRAGRADO INFORMATICA6#1ALGEBRAGRADO MECANICA6#2PROGRAMACIONGRADO INFORMATICA6';
        v_valorActual   varchar(100);
      begin
       insertaAsignatura ( 2, 'PROGRAMACION', 'GRADO INFORMATICA', 6);
       --rollback; --por si se olvido hacer commit en insertaAsignatura
       -- Elimino el rollback porque sino entiendo que va a dar error el último test siempre...

        SELECT listagg(idAsignatura||nombre||titulacion||ncreditos, '#')
          within group (order by idAsignatura, titulacion) todoJunto
        into v_valorActual
        FROM asignaturas;
      
        
        if v_valorEsperado=v_valorActual then
          dbms_output.put_line('Bien: Caso sin excepciones computado correctamente');
        else
          dbms_output.put_line('Mal: Caso sin excepciones computado incorrectamente');
          dbms_output.put_line('Valor actual=  '||v_valorActual);
          dbms_output.put_line('Valor esperado='||v_valorEsperado);
        end if;
        
   exception
        when others then
          dbms_output.put_line('Mal: Salta excepcion en el caso correcto');
          dbms_output.put_line('error='||SQLCODE||'=>'||SQLERRM);     
    end;
    
  end;
  /

set serveroutput on
exec test_asignaturas;
select * from asignaturas;
commit;


-- 2. MÉTODO CON SQLERRM ---------------------------------------------------------------------------------

create or replace procedure insertaAsignatura (
    v_idAsignatura integer, v_nombreAsig varchar, v_titulacion varchar, v_ncreditos integer) 
is
begin
    insert into asignaturas values (v_idAsignatura, v_nombreAsig, v_titulacion, v_ncreditos);
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN -- DUP_VAL_ON_INDEX es el error ORA-00001 de fallo de unicidad
        -- IF SQLERRM LIKE '%PK_Asignaturas%' THEN -- Con esta instrucción tiene que ser exactamente el valor PK....
        -- Usamos INSTR para comprobar si el mensaje de error contiene el nombre de la restricción
        IF INSTR(SQLERRM, 'PK_ASIGNATURAS') > 0 THEN
          RAISE_APPLICATION_ERROR(-20000, 'La asignatura con idAsignatura=' || v_idAsignatura || 
              ' está repetida en la titulación ' || v_titulacion || '.');
        ELSIF INSTR(SQLERRM, 'UNQ_ASIGNATURAS') > 0 THEN
          RAISE_APPLICATION_ERROR(-20001, 'La asignatura con nombre=' || v_nombreAsig || 
                  ' está repetida en la titulación ' || v_titulacion || '.');
        ELSE
          dbms_output.put_line('Mal: esto indicaría que no detecta ni sqlerrm pk_asignaturas ni unq_asignaturas');
          dbms_output.put_line('error='||SQLCODE||'=>'||SQLERRM); 
          RAISE; -- En otros casos lanzamos la excepción
        END IF;

end;
/

set serveroutput on
exec test_asignaturas;
select * from asignaturas;
commit;


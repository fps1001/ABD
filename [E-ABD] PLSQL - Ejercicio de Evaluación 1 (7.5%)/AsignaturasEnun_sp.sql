/*
Aplicaciones de Bases de Datos.
Ingeniería Informática. UBU. Curso 23-24
Fernando Pisot Serrano fps1001@alu.ubu.es
Repositorio github: https://github.com/fps1001/ABD 

[E-ABD] PL/SQL - Ejercicio de Evaluación 1 (7.5%) - 03/04
Esta vez voy a intentar realizar la práctica desde visual studio con la extensión: 
-Oracle Developer Tools for VS Code (SQL and PLSQL) 
Y la instalación de 
Oracle Instant Client Downloads for Microsoft Windows (x64) 64-bit

*/
-- Elimina la tabla 'asignaturas' si existe, incluyendo todas sus restricciones de integridad.
drop table asignaturas cascade constraints;

-- Creación de la tabla 'asignaturas' con sus respectivos campos y restricciones.
-- Campos: idAsignatura (identificador de la asignatura), nombre, titulación a la que pertenece, y número de créditos.
-- Restricciones: Una clave primaria compuesta por 'idAsignatura' y 'titulacion', y una restricción de unicidad para la combinación de 'nombre' y 'titulacion'.
create table asignaturas(
  idAsignatura  integer,
  nombre        varchar(20) not null,
  titulacion    varchar(20),
  ncreditos     integer,
  constraint PK_Asignaturas primary key ( idAsignatura, titulacion ),
  constraint UNQ_Asignaturas unique (nombre, titulacion) 
);

-- 1. MÉTODO CON SELECTS ---------------------------------------------------------------------------------
-- Las nombro diferentes para no tener que comentar/descomentar el código
create or replace procedure insertaAsignatura_con_selects(
  v_idAsignatura integer, v_nombreAsig varchar, v_titulacion varchar, v_ncreditos integer) is

BEGIN
  INSERT INTO asignaturas VALUES (
    v_idAsignatura, v_nombreAsig, v_titulacion, v_ncreditos
  );
EXCEPTION
  WHEN OTHERS THEN
  IF SQLCODE = -1 THEN -- Error ORA-00001 - Fallo de unidicidad
    SELECT COUNT(*) -- Realizamos una select
    INTO v_count
    FROM asignaturas
    WHERE idAsignatura = v_idAsignatura
    AND titulacion = v_titulacion;

    IF v_count > 0 THEN -- Si el contador es mayor que 0 indica que ya existe una fila con el mismo id-titulación
      RAISE_APPLICATION_ERROR(-20000, 'La asignatura con idAsignatura=' || v_idAsignatura || ' esta repetida en la titulacion ' || v_titulacion || '.');
    ELSE -- Si no lo tiene el fallo es debido al nombre repetido de la asignatura.
      RAISE_APPLICATION_ERROR(-20001, 'La asignatura con nombre=' || v_nombreAsig || ' esta repetida en la titulacion ' || v_titulacion || '.');
    END IF;
  ELSE
    RAISE;
  END IF;
  END;
EXCEPTION
  WHEN OTHERS THEN
    -- TODO Mirar en los apuntes qué hacer en este caso.
    ROLLBACK;
    RAISE;
END insertaAsignatura_con_selects;


-- 1. MÉTODO CON CREATE TABLE ---------------------------------------------------------------------------------

create or replace procedure insertaAsignatura_con_create(
  v_idAsignatura integer, v_nombreAsig varchar, v_titulacion varchar, v_ncreditos integer) is

BEGIN
  INSERT INTO asignaturas VALUES (
    v_idAsignatura,
    v_nombreAsig,
    v_titulacion,
    v_ncreditos
  );
EXCEPTION
  WHEN OTHERS THEN
    -- MANEJO DE EXCEPCIONES
    RAISE;
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
       rollback; --por si se olvido hacer commit en insertaAsignatura

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

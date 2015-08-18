CREATE OR REPLACE PACKAGE BODY dz_spidx_main
AS

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_XY_diminfo
   RETURN MDSYS.SDO_DIM_ARRAY
   AS
      ary_output MDSYS.SDO_DIM_ARRAY
         := MDSYS.SDO_DIM_ARRAY(
            MDSYS.SDO_DIM_ELEMENT(
               'X',
               -180,
                180,
               .05
            ),
            MDSYS.SDO_DIM_ELEMENT(
               'Y',
               -90,
                90,
               .05
            )
        );
   BEGIN
      RETURN ary_output;
      
   END get_XY_diminfo;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_XYZ_diminfo
   RETURN MDSYS.SDO_DIM_ARRAY
   AS
      ary_output MDSYS.SDO_DIM_ARRAY
      := MDSYS.SDO_DIM_ARRAY(
            MDSYS.SDO_DIM_ELEMENT(
               'X',
               -180,
                180,
               .05
            ),
            MDSYS.SDO_DIM_ELEMENT(
               'Y',
               -90,
                90,
               .05
            ),
            MDSYS.SDO_DIM_ELEMENT(
               'Z',
               -15000,
                15000,
               .05
            )
        );
   BEGIN
      RETURN ary_output;
      
   END get_XYZ_diminfo;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_XYM_diminfo
   RETURN MDSYS.SDO_DIM_ARRAY
   AS
      ary_output MDSYS.SDO_DIM_ARRAY
      := MDSYS.SDO_DIM_ARRAY(
            MDSYS.SDO_DIM_ELEMENT(
               'X',
               -180,
                180,
               .05
            ),
            MDSYS.SDO_DIM_ELEMENT(
               'Y',
               -90,
                90,
               .05
            ),
            MDSYS.SDO_DIM_ELEMENT(
               'M',
                0,
                100,
               .00001
            )
        );
   BEGIN
      RETURN ary_output;
      
   END get_XYM_diminfo;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_XYZM_diminfo
   RETURN MDSYS.SDO_DIM_ARRAY
   AS
      ary_output MDSYS.SDO_DIM_ARRAY
      := MDSYS.SDO_DIM_ARRAY(
            MDSYS.SDO_DIM_ELEMENT(
               'X',
               -180,
                180,
               .05
            ),
            MDSYS.SDO_DIM_ELEMENT(
               'Y',
               -90,
                90,
               .05
            ),
            MDSYS.SDO_DIM_ELEMENT(
               'Z',
               -15000,
                15000,
               .05
            ),
            MDSYS.SDO_DIM_ELEMENT(
               'M',
                0,
                100,
               .00001
            )
        );
   BEGIN
      RETURN ary_output;
      
   END get_XYZM_diminfo;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_XYMZ_diminfo
   RETURN MDSYS.SDO_DIM_ARRAY
   AS
      ary_output MDSYS.SDO_DIM_ARRAY
      := MDSYS.SDO_DIM_ARRAY(
            MDSYS.SDO_DIM_ELEMENT(
               'X',
               -180,
                180,
               .05
            ),
            MDSYS.SDO_DIM_ELEMENT(
               'Y',
               -90,
                90,
               .05
            ),
            MDSYS.SDO_DIM_ELEMENT(
               'M',
                0,
                100,
               .00001
            ),
            MDSYS.SDO_DIM_ELEMENT(
               'Z',
               -15000,
                15000,
               .05
            )
        );
   BEGIN
      RETURN ary_output;
      
   END get_XYMZ_diminfo;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE spatial_mview_refresh(
       list                          IN  VARCHAR2
      ,method                        IN  VARCHAR2       := NULL
      ,rollback_seg                  IN  VARCHAR2       := NULL
      ,push_deferred_rpc             IN  BOOLEAN        := TRUE
      ,refresh_after_errors          IN  BOOLEAN        := FALSE
      ,purge_option                  IN  BINARY_INTEGER := 1
      ,parallelism                   IN  BINARY_INTEGER := 0
      ,heap_size                     IN  BINARY_INTEGER := 0
      ,atomic_refresh                IN  BOOLEAN        := TRUE
      ,nested                        IN  BOOLEAN        := FALSE
   )
   AS
      ary_mv_list  MDSYS.SDO_STRING2_ARRAY;
      
      TYPE tbl_spatial_indx IS TABLE OF dz_spidx_list
      INDEX BY PLS_INTEGER;
      
      ary_spatial_indx tbl_spatial_indx;
      
   BEGIN
   
      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      ary_mv_list := dz_spidx_util.gz_split(
          p_str    => list
         ,p_regex  => ','
         ,p_trim   => 'TRUE'
      );
      
      --------------------------------------------------------------------------
      -- Step 20
      -- Verify each mview
      --------------------------------------------------------------------------
      FOR i IN 1 .. ary_mv_list.COUNT
      LOOP
         IF dz_spidx_util.mview_exists(
            p_mview_name => ary_mv_list(i)
         ) = 'FALSE'
         THEN
            RAISE_APPLICATION_ERROR(
                -20001
               ,ary_mv_list(i) || ' does not exist or is not a materialized view'
            );
            
         END IF;
         
      END LOOP;
      
      --------------------------------------------------------------------------
      -- Step 30
      -- Slurp off the spatial index information
      --------------------------------------------------------------------------
      FOR i IN 1 .. ary_mv_list.COUNT
      LOOP
         ary_spatial_indx(i) := dz_spidx_main.get_spatial_indexes(
            p_table_name   => ary_mv_list(i)
         );
         
      END LOOP;
      
      --------------------------------------------------------------------------
      -- Step 40
      -- Drop the spatial indexes
      --------------------------------------------------------------------------
      FOR i IN 1 .. ary_mv_list.COUNT
      LOOP
         dz_spidx_main.flush_spatial_indexes(
            p_table_name   => ary_mv_list(i)
         );
         
      END LOOP;
      
      --------------------------------------------------------------------------
      -- Step 50
      -- Run the refresh
      --------------------------------------------------------------------------
      DBMS_MVIEW.REFRESH (
          list                   => list
         ,method                 => method
         ,rollback_seg           => rollback_seg
         ,push_deferred_rpc      => push_deferred_rpc
         ,refresh_after_errors   => refresh_after_errors
         ,purge_option           => purge_option
         ,parallelism            => parallelism
         ,heap_size              => heap_size
         ,atomic_refresh         => atomic_refresh
         ,nested                 => nested
      );
      
      --------------------------------------------------------------------------
      -- Step 60
      -- Rebuild the spatial indexes
      --------------------------------------------------------------------------
      FOR i IN 1 .. ary_mv_list.COUNT
      LOOP
         dz_spidx_main.recreate_spatial_indexes(
            p_index_array  => ary_spatial_indx(i)
         );
         
      END LOOP;
      
   END spatial_mview_refresh;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE fast_spatial_index(
       p_owner        IN  VARCHAR2 DEFAULT NULL
      ,p_table_name   IN  VARCHAR2
      ,p_column_name  IN  VARCHAR2
      ,p_tablespace   IN  VARCHAR2 DEFAULT NULL
      ,p_dimensions   IN  VARCHAR2 DEFAULT 'XY'
      ,p_srid         IN  NUMBER   DEFAULT 8265
      ,p_x_dim_elem   IN  MDSYS.SDO_DIM_ELEMENT DEFAULT NULL
      ,p_y_dim_elem   IN  MDSYS.SDO_DIM_ELEMENT DEFAULT NULL
      ,p_z_dim_elem   IN  MDSYS.SDO_DIM_ELEMENT DEFAULT NULL
      ,p_m_dim_elem   IN  MDSYS.SDO_DIM_ELEMENT DEFAULT NULL
   )
   AS
      num_srid        NUMBER       := p_srid;
      str_owner       VARCHAR2(30) := UPPER(p_owner);
      obj_spidx       dz_spidx;
      int_counter     PLS_INTEGER;
      
   BEGIN

      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      IF p_table_name IS NULL
      THEN
         RAISE_APPLICATION_ERROR(-20001,'must provide table name');
         
      END IF;

      IF p_column_name IS NULL
      THEN
         RAISE_APPLICATION_ERROR(-20001,'must provide column name');
         
      END IF;

      IF num_srid IS NULL
      THEN
         num_srid := 8265;
         
      END IF;
      
      IF p_dimensions IS NULL
      AND p_x_dim_elem IS NULL
      AND p_y_dim_elem IS NULL
      THEN
         RAISE_APPLICATION_ERROR(-20001,'must provide dim elem info');
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 20
      -- Get the owner information
      --------------------------------------------------------------------------
      IF str_owner IS NULL
      THEN
         str_owner := USER;
      
      END IF;

      --------------------------------------------------------------------------
      -- Step 30
      -- Create the object
      --------------------------------------------------------------------------
      obj_spidx := dz_spidx(
           p_table_owner    => str_owner
          ,p_table_name     => p_table_name
          ,p_column_name    => p_column_name
      );
      
      IF p_tablespace IS NOT NULL
      THEN
         obj_spidx.index_parameters := 'TABLESPACE = ' || p_tablespace;
         
      END IF;
      
      IF p_dimensions IS NOT NULL
      THEN
         obj_spidx.redefine_index(
             p_srid    => num_srid
            ,p_keyword => p_dimensions
         );
      
      ELSE
         int_counter := 3;
         obj_spidx.geometry_srid := num_srid;
         obj_spidx.geometry_dim_array := MDSYS.SDO_DIM_ARRAY();
         
         obj_spidx.geometry_dim_array.EXTEND(2);
         obj_spidx.geometry_dim_array(1) := p_x_dim_elem;
         obj_spidx.geometry_dim_array(2) := p_y_dim_elem;
         IF p_z_dim_elem IS NOT NULL
         THEN
            obj_spidx.geometry_dim_array.EXTEND();
            obj_spidx.geometry_dim_array(int_counter) := p_z_dim_elem;
            int_counter := int_counter + 1;
            
         END IF;
         
         IF p_m_dim_elem IS NOT NULL
         THEN
            obj_spidx.geometry_dim_array.EXTEND();
            obj_spidx.geometry_dim_array(int_counter) := p_m_dim_elem;
            int_counter := int_counter + 1;
            
         END IF;
         
         obj_spidx.update_sdo_metadata();
         
         obj_spidx.create_index();
         
      END IF;

   END fast_spatial_index;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_spatial_indexes(
       p_owner       IN  VARCHAR2 DEFAULT NULL
      ,p_table_name  IN  VARCHAR2
   ) RETURN dz_spidx_list
   AS
      str_owner       VARCHAR2(30) := UPPER(p_owner);
      ary_index_owner MDSYS.SDO_STRING2_ARRAY;
      ary_index_name  MDSYS.SDO_STRING2_ARRAY;
      ary_spx         dz_spidx_list;
      
   BEGIN
   
      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      IF str_owner IS NULL
      THEN
         str_owner := USER;
      
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 20
      -- Collect the list of indexes
      --------------------------------------------------------------------------
      SELECT 
       a.owner
      ,a.index_name 
      BULK COLLECT INTO 
       ary_index_owner
      ,ary_index_name
      FROM 
      all_indexes a 
      WHERE 
          a.table_owner = str_owner
      AND a.table_name = p_table_name
      AND a.ityp_owner = 'MDSYS'
      AND a.ityp_name = 'SPATIAL_INDEX';
      
      --------------------------------------------------------------------------
      -- Step 30
      -- Exit early if needed
      --------------------------------------------------------------------------
      ary_spx := dz_spidx_list();
      IF ary_index_owner IS NULL
      OR ary_index_owner.COUNT = 0
      THEN
         RETURN ary_spx;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 40
      -- Build the object list
      --------------------------------------------------------------------------
      ary_spx.EXTEND(ary_index_owner.COUNT);
      FOR i IN 1 .. ary_index_owner.COUNT
      LOOP
         ary_spx(i) := dz_spidx(
            p_index_owner => ary_index_owner(i),
            p_index_name  => ary_index_name(i)
         );
         
      END LOOP;
      
      RETURN ary_spx;
   
   END get_spatial_indexes;   
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE flush_spatial_indexes(
       p_owner      IN  VARCHAR2 DEFAULT NULL
      ,p_table_name IN  VARCHAR2
      ,p_output     OUT MDSYS.SDO_STRING2_ARRAY
   )
   AS
      str_owner  VARCHAR2(30) := UPPER(p_owner);
      ary_spx    dz_spidx_list;
      
   BEGIN
   
      IF str_owner IS NULL
      THEN
         str_owner := USER;
         
      END IF;
   
      ary_spx := get_spatial_indexes(
          p_owner      => str_owner
         ,p_table_name => p_table_name
      );
      p_output := MDSYS.SDO_STRING2_ARRAY();
      
      FOR i IN 1 .. ary_spx.COUNT
      LOOP
         p_output.EXTEND();
         EXECUTE IMMEDIATE ary_spx(i).drop_index();
         p_output(i) := ary_spx(i).index_name;
         
      END LOOP;
   
   END flush_spatial_indexes; 
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE flush_spatial_indexes(
       p_owner      IN  VARCHAR2 DEFAULT NULL
      ,p_table_name IN  VARCHAR2
   )
   AS
      ary_spx     dz_spidx_list;
      
   BEGIN
   
      ary_spx := flush_spatial_indexes(
          p_owner      => p_owner
         ,p_table_name => p_table_name
      );
   
   END flush_spatial_indexes; 
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION flush_spatial_indexes(
       p_owner        IN  VARCHAR2 DEFAULT NULL
      ,p_table_name   IN  VARCHAR2
   ) RETURN dz_spidx_list
   AS
      str_owner VARCHAR2(30) := UPPER(p_owner);
      ary_spx   dz_spidx_list;
      
   BEGIN
   
      IF str_owner IS NULL
      THEN
         str_owner := USER;
         
      END IF;
   
      ary_spx := get_spatial_indexes(
          p_owner      => str_owner
         ,p_table_name => p_table_name
      );
      
      FOR i IN 1 .. ary_spx.COUNT
      LOOP
         EXECUTE IMMEDIATE ary_spx(i).drop_index();
         
      END LOOP;
      
      RETURN ary_spx;
   
   END flush_spatial_indexes; 
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE recreate_spatial_indexes(
      p_index_array  IN  dz_spidx_list
   )
   AS
      ary_indexes  dz_spidx_list;
      
   BEGIN
   
      ary_indexes := p_index_array;
   
      FOR i IN 1 .. ary_indexes.COUNT
      LOOP
         EXECUTE IMMEDIATE ary_indexes(i).create_index();
         
      END LOOP;
   
   END recreate_spatial_indexes;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE rebuild_user_spatial(
       p_filter       IN  VARCHAR2
      ,p_tablespace   IN  VARCHAR2 DEFAULT NULL
      ,p_quiet        IN  VARCHAR2 DEFAULT 'FALSE'
   )
   AS
      str_filter     VARCHAR2(4000) := UPPER(p_filter);
      str_quiet      VARCHAR2(4000) := UPPER(p_quiet);
      ary_tables     MDSYS.SDO_STRING2_ARRAY;
      ary_columns    MDSYS.SDO_STRING2_ARRAY;
      ary_colnums    MDSYS.SDO_NUMBER_ARRAY;
      ary_indexes    MDSYS.SDO_STRING2_ARRAY;
      str_tablespace_blurb VARCHAR2(4000);
      str_indexname  VARCHAR2(30);
      str_sql        VARCHAR2(4000);
      
   BEGIN
      
      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------      
      IF str_quiet IS NULL
      THEN
         str_quiet := 'FALSE';
         
      END IF;
      
      IF p_tablespace IS NOT NULL
      THEN
         IF dz_spidx_util.tablespace_exists(p_tablespace) = 'FALSE'
         THEN
            IF str_quiet = 'FALSE'
            THEN
               RAISE_APPLICATION_ERROR(
                   -20001
                  ,'tablespace ' || p_tablespace || ' does not exist '
               );
                              
            END IF;
            
            str_tablespace_blurb := NULL;
         
         ELSE   
            str_tablespace_blurb := 'TABLESPACE = ' || p_tablespace;
         
         END IF;   
      
      END IF;
      --------------------------------------------------------------------------
      -- Step 20
      -- Get the list of tables that match the filter
      --------------------------------------------------------------------------
      IF str_filter IS NULL
      THEN
         SELECT
         a.table_name
         BULK COLLECT INTO ary_tables
         FROM
         user_tables a
         WHERE
         a.table_name IN (
            SELECT 
            b.table_name 
            FROM 
            user_tab_columns b
            WHERE 
            b.data_type IN ('SDO_GEOMETRY','MDSYS.SDO_GEOMETRY')
         ) AND
         a.table_name IN (
            SELECT
            c.table_name
            FROM
            user_sdo_geom_metadata c
         );
         
         IF ary_tables IS NULL
         OR ary_tables.COUNT = 0
         THEN
            IF str_quiet = 'FALSE'
            THEN
               dbms_output.put_line('No table names with registered geometry found in schema');
            END IF;
            RETURN;
            
         END IF;
      
      ELSE
         SELECT
         a.table_name
         BULK COLLECT INTO ary_tables
         FROM
         user_tables a
         WHERE
         a.table_name LIKE '%' || str_filter || '%' AND
         a.table_name IN (
            SELECT 
            b.table_name 
            FROM 
            user_tab_columns b
            WHERE 
            b.data_type IN ('SDO_GEOMETRY','MDSYS.SDO_GEOMETRY')
         ) AND
         a.table_name IN (
            SELECT
            c.table_name
            FROM
            user_sdo_geom_metadata c
         );
         
         IF ary_tables IS NULL
         OR ary_tables.COUNT = 0
         THEN
            IF str_quiet = 'FALSE'
            THEN
               dbms_output.put_line('No table names with registered geometry match the input filter');
            END IF;
            RETURN;
         
         END IF;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 30
      -- Process each table and column
      --------------------------------------------------------------------------
      FOR i IN 1 .. ary_tables.COUNT
      LOOP
      
         --- Drop all the spatial indexes on the table
         flush_spatial_indexes(
             p_table_name => ary_tables(i)
            ,p_output     => ary_indexes
         );
         
         IF str_quiet = 'FALSE'
         THEN
            FOR j IN 1 .. ary_indexes.COUNT
            LOOP
               dbms_output.put_line('DROPPING spatial index ' || ary_indexes(j));
            END LOOP;
            
         END IF;
         
         SELECT
          a.column_name
         ,b.column_id
         BULK COLLECT INTO ary_columns,ary_colnums
         FROM
         user_sdo_geom_metadata a
         JOIN
         user_tab_columns b
         ON
         a.table_name = b.table_name AND
         a.column_name = b.column_name
         WHERE
         a.table_name = ary_tables(i);
         
         FOR j IN 1 .. ary_columns.COUNT
         LOOP
            IF ary_columns.COUNT = 1
            THEN
               str_indexname := dz_spidx_util.get_index_name(
                  p_table_name   => ary_tables(i),
                  p_column_name  => ary_columns(j),
                  p_full_suffix  => 'SPX'
               );
               
            ELSE
               str_indexname := dz_spidx_util.get_index_name(
                  p_table_name   => ary_tables(i),
                  p_column_name  => ary_columns(j),
                  p_suffix_ind   => 'S'
               );
               
            END IF;
               
            str_sql := 'CREATE INDEX ' || str_indexname || ' '
                    || 'ON ' || ary_tables(i) || '(' || ary_columns(j) || ') '
                    || 'INDEXTYPE IS MDSYS.SPATIAL_INDEX ';

            IF str_tablespace_blurb IS NOT NULL
            THEN
               str_sql := str_sql
                       || 'PARAMETERS('' '|| str_tablespace_blurb || ' '') ';
            END IF;
            
            BEGIN
               EXECUTE IMMEDIATE str_sql;
            EXCEPTION
               WHEN OTHERS
               THEN
                  dbms_output.put_line(str_sql);
                  RAISE;
            END;
            
            IF str_quiet = 'FALSE'
            THEN
               dbms_output.put_line('Building new spatial index ' || str_indexname 
                  || ' ON table ' || ary_tables(i) 
                  || ' ON column ' || ary_columns(j)
               );
               
            END IF;
         
         END LOOP;
      
      END LOOP;
      
   END rebuild_user_spatial;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE sdo_join_check(
       p_table_name1        IN  VARCHAR2
      ,p_column_name1       IN  VARCHAR2
      ,p_table_name2        IN  VARCHAR2
      ,p_column_name2       IN  VARCHAR2
      ,p_return_code        OUT NUMBER
      ,p_status_message     OUT VARCHAR2
   )
   AS
      str_owner1        VARCHAR2(30);
      str_table1        VARCHAR2(30);
      str_owner2        VARCHAR2(30);
      str_table2        VARCHAR2(30);
      num_counter1      PLS_INTEGER;
      num_counter2      PLS_INTEGER;
      str_spidx_owner1  VARCHAR2(30);
      str_spidx_table1  VARCHAR2(30);
      str_spidx_owner2  VARCHAR2(30);
      str_spidx_table2  VARCHAR2(30);
      
   BEGIN
   
      dz_spidx_util.parse_schema(
          p_input       => p_table_name1
         ,p_schema      => str_owner1
         ,p_object_name => str_table1
      );
      
      IF str_owner1 IS NULL
      THEN
         str_owner1 := USER;
      
      END IF;
      
      dz_spidx_util.parse_schema(
          p_input       => p_table_name2
         ,p_schema      => str_owner2
         ,p_object_name => str_table2
      );
       
      IF str_owner2 IS NULL
      THEN
         str_owner2 := USER;
      
      END IF;
      
      dz_spidx_util.spatial_index_table(
          p_owner          => str_owner1
         ,p_table_name     => str_table1
         ,p_column_name    => p_column_name1
         ,p_out_owner      => str_spidx_owner1
         ,p_out_table_name => str_spidx_table1
      );
      
      IF str_spidx_table1 IS NULL
      THEN
         p_return_code := -1;
         p_status_message := 'No spatial index found on ' || p_table_name1;
         RETURN;
         
      END IF;
      
      dz_spidx_util.spatial_index_table(
          p_owner          => str_owner2
         ,p_table_name     => str_table2
         ,p_column_name    => p_column_name2
         ,p_out_owner      => str_spidx_owner2
         ,p_out_table_name => str_spidx_table2
      );
      
      IF str_spidx_table2 IS NULL
      THEN
         p_return_code := -2;
         p_status_message := 'No spatial index found on ' || p_table_name2;
         RETURN;
         
      END IF;
      
      IF str_spidx_owner1 = USER
      THEN
         num_counter1 := 1;
         
      ELSE
         SELECT
         COUNT(*)
         INTO
         num_counter1
         FROM
         all_tab_privs a
         WHERE
             a.table_schema = str_spidx_owner1
         AND a.table_name = str_spidx_table1;
         
      END IF;
      
      IF str_spidx_owner2 = USER
      THEN
         num_counter2 := 1;
         
      ELSE
         SELECT
         COUNT(*)
         INTO
         num_counter2
         FROM
         all_tab_privs a
         WHERE
             a.table_schema = str_spidx_owner2
         AND a.table_name = str_spidx_table2;
      
      END IF;
      
      IF num_counter1 <> 1
      AND num_counter2 <> 1
      THEN
         p_return_code := -4;
         p_status_message := 'No SELECT privs on ' || str_spidx_owner1 || '.' || str_spidx_table1 ||
         ' or ' || str_spidx_owner2 || '.' || str_spidx_table2 ;
         
      ELSIF num_counter1 <> 1
      THEN
         p_return_code := -3;
         p_status_message := 'No SELECT privs on ' || str_spidx_owner1 || '.' || str_spidx_table1;
         
      ELSIF num_counter2 <> 1
      THEN
         p_return_code := -3;
         p_status_message := 'No SELECT privs on ' || str_spidx_owner2 || '.' || str_spidx_table2;
         
      ELSE
         p_return_code := 0;
         
      END IF;
      
   END sdo_join_check;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION sdo_join_check(
       p_table_name1        IN  VARCHAR2
      ,p_column_name1       IN  VARCHAR2
      ,p_table_name2        IN  VARCHAR2
      ,p_column_name2       IN  VARCHAR2
   ) RETURN VARCHAR2
   AS
      num_return_code    NUMBER;
      str_status_message VARCHAR2(4000);
      
   BEGIN
      sdo_join_check(
          p_table_name1    => p_table_name1
         ,p_column_name1   => p_column_name1
         ,p_table_name2    => p_table_name2
         ,p_column_name2   => p_column_name2
         ,p_return_code    => num_return_code
         ,p_status_message => str_status_message
      );
   
      IF num_return_code = 0
      THEN
         RETURN 'TRUE';
         
      ELSE
         RETURN 'FALSE';
         
      END IF;
   
   END sdo_join_check;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION sdo_join_check_verbose(
       p_table_name1        IN  VARCHAR2
      ,p_column_name1       IN  VARCHAR2
      ,p_table_name2        IN  VARCHAR2
      ,p_column_name2       IN  VARCHAR2
   ) RETURN VARCHAR2
   AS
      num_return_code    NUMBER;
      str_status_message VARCHAR2(4000);
      
   BEGIN
      sdo_join_check(
          p_table_name1    => p_table_name1
         ,p_column_name1   => p_column_name1
         ,p_table_name2    => p_table_name2
         ,p_column_name2   => p_column_name2
         ,p_return_code    => num_return_code
         ,p_status_message => str_status_message
      );
   
      IF num_return_code = 0
      THEN
         RETURN 'TRUE';
         
      ELSE
         RETURN str_status_message;
         
      END IF;
   
   END sdo_join_check_verbose;
   
END dz_spidx_main;
/


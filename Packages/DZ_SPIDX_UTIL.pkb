CREATE OR REPLACE PACKAGE BODY dz_spidx_util
AS

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION gz_split(
       p_str         IN  VARCHAR2
      ,p_regex       IN  VARCHAR2
      ,p_match       IN  VARCHAR2 DEFAULT NULL
      ,p_end         IN  NUMBER   DEFAULT 0
      ,p_trim        IN  VARCHAR2 DEFAULT 'FALSE'
   ) RETURN MDSYS.SDO_STRING2_ARRAY DETERMINISTIC 
   AS
      int_delim      PLS_INTEGER;
      int_position   PLS_INTEGER := 1;
      int_counter    PLS_INTEGER := 1;
      ary_output     MDSYS.SDO_STRING2_ARRAY;
      num_end        NUMBER      := p_end;
      str_trim       VARCHAR2(5 Char) := UPPER(p_trim);
      
      FUNCTION trim_varray(
         p_input            IN MDSYS.SDO_STRING2_ARRAY
      ) RETURN MDSYS.SDO_STRING2_ARRAY
      AS
         ary_output MDSYS.SDO_STRING2_ARRAY := MDSYS.SDO_STRING2_ARRAY();
         int_index  PLS_INTEGER := 1;
         str_check  VARCHAR2(4000 Char);
         
      BEGIN

         --------------------------------------------------------------------------
         -- Step 10
         -- Exit if input is empty
         --------------------------------------------------------------------------
         IF p_input IS NULL
         OR p_input.COUNT = 0
         THEN
            RETURN ary_output;
            
         END IF;

         --------------------------------------------------------------------------
         -- Step 20
         -- Trim the strings removing anything utterly trimmed away
         --------------------------------------------------------------------------
         FOR i IN 1 .. p_input.COUNT
         LOOP
            str_check := TRIM(p_input(i));
            
            IF str_check IS NULL
            OR str_check = ''
            THEN
               NULL;
               
            ELSE
               ary_output.EXTEND(1);
               ary_output(int_index) := str_check;
               int_index := int_index + 1;
               
            END IF;

         END LOOP;

         --------------------------------------------------------------------------
         -- Step 10
         -- Return the results
         --------------------------------------------------------------------------
         RETURN ary_output;

      END trim_varray;

   BEGIN

      --------------------------------------------------------------------------
      -- Step 10
      -- Create the output array and check parameters
      --------------------------------------------------------------------------
      ary_output := MDSYS.SDO_STRING2_ARRAY();

      IF str_trim IS NULL
      THEN
         str_trim := 'FALSE';
         
      ELSIF str_trim NOT IN ('TRUE','FALSE')
      THEN
         RAISE_APPLICATION_ERROR(-20001,'boolean error');
         
      END IF;

      IF num_end IS NULL
      THEN
         num_end := 0;
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 20
      -- Exit early if input is empty
      --------------------------------------------------------------------------
      IF p_str IS NULL
      OR p_str = ''
      THEN
         RETURN ary_output;
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 30
      -- Account for weird instance of pure character breaking
      --------------------------------------------------------------------------
      IF p_regex IS NULL
      OR p_regex = ''
      THEN
         FOR i IN 1 .. LENGTH(p_str)
         LOOP
            ary_output.EXTEND(1);
            ary_output(i) := SUBSTR(p_str,i,1);
            
         END LOOP;
         
         RETURN ary_output;
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 40
      -- Break string using the usual REGEXP functions
      --------------------------------------------------------------------------
      LOOP
         EXIT WHEN int_position = 0;
         int_delim  := REGEXP_INSTR(p_str,p_regex,int_position,1,0,p_match);
         
         IF  int_delim = 0
         THEN
            -- no more matches found
            ary_output.EXTEND(1);
            ary_output(int_counter) := SUBSTR(p_str,int_position);
            int_position  := 0;
            
         ELSE
            IF int_counter = num_end
            THEN
               -- take the rest as is
               ary_output.EXTEND(1);
               ary_output(int_counter) := SUBSTR(p_str,int_position);
               int_position  := 0;
               
            ELSE
               --dbms_output.put_line(ary_output.COUNT);
               ary_output.EXTEND(1);
               ary_output(int_counter) := SUBSTR(p_str,int_position,int_delim-int_position);
               int_counter := int_counter + 1;
               int_position := REGEXP_INSTR(p_str,p_regex,int_position,1,1,p_match);
               
            END IF;
            
         END IF;
         
      END LOOP;

      --------------------------------------------------------------------------
      -- Step 50
      -- Trim results if so desired
      --------------------------------------------------------------------------
      IF str_trim = 'TRUE'
      THEN
         RETURN trim_varray(
            p_input => ary_output
         );
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 60
      -- Cough out the results
      --------------------------------------------------------------------------
      RETURN ary_output;
      
   END gz_split;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE parse_schema(
       p_input                IN  VARCHAR2
      ,p_schema               OUT VARCHAR2
      ,p_object_name          OUT VARCHAR2
   )
   AS
      ary_parts MDSYS.SDO_STRING2_ARRAY;
      
   BEGIN

      IF p_input IS NULL
      THEN
         RAISE_APPLICATION_ERROR(-20001,'input to procedure cannot be NULL');
         
      END IF;

      ary_parts := gz_split(
         p_str   => p_input,
         p_regex => '\.'
      );

      IF ary_parts.COUNT = 1
      THEN
         p_schema      := USER;
         p_object_name := UPPER(ary_parts(1));
         
      ELSIF ary_parts.COUNT = 2
      THEN
         p_schema      := UPPER(ary_parts(1));
         p_object_name := UPPER(ary_parts(2));
         
      ELSE
         RAISE_APPLICATION_ERROR(-20001,'cannot parse out schema from ' || p_input);
         
      END IF;

   END parse_schema;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION scrunch_name(
       p_input       IN  VARCHAR2
      ,p_max_length  IN  NUMBER DEFAULT 27
      ,p_method      IN  VARCHAR2 DEFAULT 'SUBSTR'
   ) RETURN VARCHAR2
   AS
      num_max_length NUMBER := p_max_length;
      str_input      VARCHAR2(4000 Char) := UPPER(p_input);
      str_method     VARCHAR2(4000 Char) := p_method;
      str_temp       VARCHAR2(4000 Char);
      
      FUNCTION drop_vowel(
         p_input   IN  VARCHAR2
      ) RETURN VARCHAR2
      AS
         str_input VARCHAR2(4000 Char) := p_input;
         str_temp  VARCHAR2(4000 Char);
         
      BEGIN
         str_temp := REGEXP_REPLACE(str_input,'[AEIOU]([^A^E^I^O^U]*$)','\1');
         
         IF LENGTH(str_temp) = LENGTH(str_input) - 1
         THEN
            IF SUBSTR(str_input,1,1) IN ('A','E','I','O','U') AND 
            SUBSTR(str_temp,1,1) NOT IN ('A','E','I','O','U')
            THEN
               NULL;
               
            ELSE
               RETURN str_temp;
               
            END IF;
            
         END IF;

         RETURN p_input;
         
      END drop_vowel;
      
   BEGIN
   
      IF num_max_length IS NULL
      THEN
         num_max_length := 27;
         
      END IF;
      
      IF str_method IS NULL
      THEN
         str_method := 'SUBSTR';
         
      END IF; 

      IF LENGTH(str_input) <= num_max_length
      THEN
         RETURN str_input;
         
      END IF;
      
      IF str_method = 'SUBSTR'
      THEN
         RETURN SUBSTR(str_input,1,num_max_length);
         
      ELSIF str_method = 'VOWELS'
      THEN
         str_temp := str_input;
         
         FOR i IN num_max_length .. LENGTH(str_input)
         LOOP
            str_temp := drop_vowel(str_temp);
            
         END LOOP;
         
         IF LENGTH(str_temp) <= num_max_length
         THEN
            RETURN str_temp;
            
         END IF;
         
         str_temp := REPLACE(str_temp,'_','');
         
         RETURN SUBSTR(str_temp,1,num_max_length);
         
      ELSE
         RAISE_APPLICATION_ERROR(-20001,'err');
         
      END IF;  
      
   END scrunch_name;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION tablespace_exists(
      p_tablespace_name IN VARCHAR2
   ) RETURN VARCHAR2
   AS
      str_tablespace_name VARCHAR2(4000 Char) := UPPER(p_tablespace_name);
      num_check           NUMBER;
      
   BEGIN
   
      SELECT
      COUNT(*)
      INTO num_check
      FROM
      user_tablespaces a
      WHERE
      a.tablespace_name = str_tablespace_name;
      
      IF num_check = 1
      THEN
         RETURN 'TRUE';
         
      ELSE
         RETURN 'FALSE';
         
      END IF;
   
   END tablespace_exists;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_column_number(
       p_owner           IN VARCHAR2 DEFAULT NULL
      ,p_table_name      IN VARCHAR2
      ,p_column_name     IN VARCHAR2
   ) RETURN NUMBER
   AS
      str_owner        VARCHAR2(30 Char) := UPPER(p_owner);
      num_columnid     NUMBER;

   BEGIN

      SELECT 
      a.column_id
      INTO num_columnid 
      FROM 
      all_tab_columns a 
      WHERE 
          a.owner = str_owner
      AND a.table_name = p_table_name
      AND a.column_name = p_column_name;
      
      RETURN num_columnid;

   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RAISE_APPLICATION_ERROR(-20001,'ERROR, no column name '
            || p_column_name || ' found in '
            || str_owner || '.' || p_table_name || '!');
            
      WHEN OTHERS
      THEN
         RAISE;

   END get_column_number;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_index_name(
       p_owner        IN  VARCHAR2 DEFAULT NULL
      ,p_table_name   IN  VARCHAR2
      ,p_column_name  IN  VARCHAR2
      ,p_suffix_ind   IN  VARCHAR2 DEFAULT 'I'
      ,p_full_suffix  IN  VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2
   AS
      str_columnid    VARCHAR2(16 Char);
      str_suffix_ind  VARCHAR2(1 Char) := UPPER(p_suffix_ind);
      str_full_suffix VARCHAR2(3 Char) := SUBSTR(UPPER(p_full_suffix),1,3);
      str_index_name  VARCHAR2(60 Char);
      str_table_base  VARCHAR2(30 Char);
      str_table_name  VARCHAR2(30 Char);

   BEGIN
   
      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      
      --------------------------------------------------------------------------
      -- Step 20
      -- get the truncated tablename as a base
      --------------------------------------------------------------------------
      str_table_base := scrunch_name(
          p_input      => str_table_name
         ,p_max_length => 27
         ,p_method     => 'VOWELS'
      );
      
      --------------------------------------------------------------------------
      -- Step 30
      -- get the column id number
      --------------------------------------------------------------------------
      IF str_full_suffix IS NOT NULL
      THEN
         str_columnid := '_' || str_full_suffix;
      
      ELSE
         str_columnid := TO_CHAR(
            get_column_number(
                p_owner       => p_owner
               ,p_table_name  => p_table_name
               ,p_column_name => p_column_name
            )
         );

         IF LENGTH(str_columnid) = 1
         THEN
            str_columnid := '_0' || str_columnid || str_suffix_ind;
            
         ELSIF LENGTH(str_columnid) = 2
         THEN
            str_columnid := '_' || str_columnid || str_suffix_ind;
            
         ELSE
            str_columnid := str_columnid || str_suffix_ind;
            
         END IF;
         
      END IF;

      str_index_name := str_table_base || str_columnid;

      RETURN UPPER(str_index_name);

   END get_index_name;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION index_exists(
       p_owner          IN  VARCHAR2 DEFAULT NULL
      ,p_index_name     IN  VARCHAR2
   ) RETURN VARCHAR2
   AS
      num_counter    NUMBER;
      str_owner      VARCHAR2(30 Char) := UPPER(p_owner);

   BEGIN

      IF str_owner IS NULL
      THEN
         str_owner := USER;
         
      END IF;

      SELECT 
      COUNT(*) 
      INTO num_counter
      FROM 
      all_indexes a 
      WHERE 
          a.table_owner = str_owner
      AND a.index_name  = p_index_name;

      IF num_counter = 0
      THEN
         RETURN 'FALSE';
         
      ELSIF num_counter = 1
      THEN
         RETURN 'TRUE';
         
      ELSE
         RAISE_APPLICATION_ERROR(-20001,'found weird indexes');
         
      END IF;

   END index_exists;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION index_exists(
       p_owner          IN  VARCHAR2 DEFAULT NULL
      ,p_table_name     IN  VARCHAR2
      ,p_column_name    IN  VARCHAR2
      ,p_index_type     IN  VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2
   AS
      num_counter    NUMBER;
      str_owner      VARCHAR2(30 Char) := UPPER(p_owner);
      str_index_type VARCHAR2(30 Char) := UPPER(p_index_type);
      
   BEGIN

      IF str_owner IS NULL
      THEN
         str_owner := USER;
         
      END IF;

      IF str_index_type IS NULL
      THEN
         SELECT 
         COUNT(*) 
         INTO num_counter
         FROM 
         all_ind_columns a
         WHERE 
             a.table_owner = str_owner
         AND a.table_name  = p_table_name
         AND a.column_name = p_column_name;
      
      ELSE
         SELECT 
         COUNT(*) 
         INTO num_counter
         FROM 
         all_indexes a
         JOIN
         all_ind_columns b
         ON
             a.owner       = b.index_owner
         AND a.index_name  = b.index_name
         WHERE 
             a.table_owner = str_owner
         AND a.table_name  = p_table_name
         AND b.column_name = p_column_name
         AND a.index_type  = str_index_type;
         
      END IF;
      
      IF num_counter = 0
      THEN
         RETURN 'FALSE';
         
      ELSIF num_counter = 1
      THEN
         RETURN 'TRUE';
         
      ELSE
         RAISE_APPLICATION_ERROR(-20001,'found weird indexes');
         
      END IF;

   END index_exists;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION table_exists(
       p_owner          IN  VARCHAR2 DEFAULT NULL
      ,p_table_name     IN  VARCHAR2
      ,p_column_name    IN  VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2
   AS
      str_owner VARCHAR2(30 Char) := UPPER(p_owner);
      num_tab   PLS_INTEGER;

   BEGIN

      IF str_owner IS NULL
      THEN
         str_owner := USER;
      
      END IF;

      IF p_column_name IS NULL
      THEN
         SELECT 
         COUNT(*) 
         INTO num_tab
         FROM (
            SELECT 
             aa.owner 
            ,aa.table_name 
            FROM 
            all_tables aa 
            UNION ALL 
            SELECT 
             bb.owner 
            ,bb.view_name AS table_name 
            FROM 
            all_views bb 
         ) a 
         WHERE 
             a.owner = str_owner
         AND a.table_name = p_table_name;

      ELSE
         SELECT 
         COUNT(*) 
         INTO num_tab
         FROM (
            SELECT 
             aa.owner 
            ,aa.table_name 
            FROM 
            all_tables aa 
            UNION ALL 
            SELECT 
             bb.owner 
            ,bb.view_name AS table_name
            FROM 
            all_views bb
         ) a 
         JOIN 
         all_tab_cols b 
         ON 
             a.owner = b.owner 
         AND a.table_name = b.table_name 
         WHERE 
            a.owner = str_owner 
        AND a.table_name = p_table_name 
        AND b.column_name = p_column_name;

      END IF;

      IF num_tab = 0
      THEN
         RETURN 'FALSE';
         
      ELSE
         RETURN 'TRUE';
         
      END IF;

   END table_exists;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION mview_exists(
       p_owner       IN  VARCHAR2 DEFAULT NULL
      ,p_mview_name  IN  VARCHAR2
   ) RETURN VARCHAR2
   AS
      str_owner   VARCHAR2(30 Char) := UPPER(p_owner);
      num_tab     PLS_INTEGER;

   BEGIN

      IF str_owner IS NULL
      THEN
         str_owner := USER;
      
      END IF;

      SELECT 
      COUNT(*) 
      INTO num_tab 
      FROM
      all_mviews a
      WHERE 
      a.owner = str_owner AND
      a.mview_name = p_mview_name;

      IF num_tab = 0
      THEN
         RETURN 'FALSE';
         
      ELSE
         RETURN 'TRUE';
         
      END IF;

   END mview_exists;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE get_spatial_index_name(
       p_owner          IN  VARCHAR2 DEFAULT NULL
      ,p_table_name     IN  VARCHAR2
      ,p_column_name    IN  VARCHAR2
      ,p_out_owner      OUT VARCHAR2
      ,p_out_index_name OUT VARCHAR2
   )
   AS
      str_owner   VARCHAR2(30 Char) := UPPER(p_owner);
      
   BEGIN
   
      IF str_owner IS NULL
      THEN
         str_owner := USER;
      
      END IF;
      
      SELECT
       b.index_owner
      ,b.index_name
      INTO
       p_out_owner
      ,p_out_index_name
      FROM
      all_indexes a
      JOIN
      all_ind_columns b
      ON
          a.owner = b.index_owner
      AND a.index_name = b.index_name
      WHERE
          a.index_type = 'DOMAIN'
      AND a.ityp_owner = 'MDSYS'
      AND b.table_owner = str_owner
      AND b.table_name = p_table_name
      AND b.column_name = p_column_name;
   
   EXCEPTION
   
      WHEN NO_DATA_FOUND
      THEN
         RETURN;
         
      WHEN OTHERS
      THEN
         RAISE;
   
   END get_spatial_index_name;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE spatial_index_table(
       p_owner          IN  VARCHAR2 DEFAULT NULL
      ,p_table_name     IN  VARCHAR2
      ,p_column_name    IN  VARCHAR2
      ,p_out_owner      OUT VARCHAR2
      ,p_out_table_name OUT VARCHAR2
   )
   AS
      str_owner       VARCHAR2(30 Char) := UPPER(p_owner);
      str_index_owner VARCHAR2(30 Char);
      str_index_name  VARCHAR2(30 Char);
      
   BEGIN
   
      IF str_owner IS NULL
      THEN
         str_owner := USER;
      
      END IF;
   
      get_spatial_index_name(
          p_owner          => str_owner
         ,p_table_name     => p_table_name
         ,p_column_name    => p_column_name
         ,p_out_owner      => str_index_owner
         ,p_out_index_name => str_index_name
      );
      
      IF str_index_name IS NULL
      THEN
         RETURN;
         
      END IF;
      
      BEGIN
         SELECT
          a.sdo_index_owner
         ,a.sdo_index_table
         INTO
          p_out_owner
         ,p_out_table_name
         FROM
         all_sdo_index_info a
         WHERE
             a.sdo_index_owner = str_owner
         AND a.index_name  = str_index_name;
      
      EXCEPTION
      
         WHEN NO_DATA_FOUND
         THEN
            RETURN;
            
         WHEN OTHERS
         THEN
            RAISE;
      
      END;
   
   END spatial_index_table;
   
END dz_spidx_util;
/


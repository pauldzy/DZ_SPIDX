
--*************************--
PROMPT sqlplus_header.sql;

WHENEVER SQLERROR EXIT -99;
WHENEVER OSERROR  EXIT -98;
SET DEFINE OFF;



--*************************--
PROMPT DZ_SPIDX_UTIL.pks;

CREATE OR REPLACE PACKAGE dz_spidx_util
AUTHID CURRENT_USER
AS
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION gz_split(
       p_str         IN  VARCHAR2
      ,p_regex       IN  VARCHAR2
      ,p_match       IN  VARCHAR2 DEFAULT NULL
      ,p_end         IN  NUMBER   DEFAULT 0
      ,p_trim        IN  VARCHAR2 DEFAULT 'FALSE'
   ) RETURN MDSYS.SDO_STRING2_ARRAY DETERMINISTIC;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE parse_schema(
       p_input                IN  VARCHAR2
      ,p_schema               OUT VARCHAR2
      ,p_object_name          OUT VARCHAR2
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION scrunch_name(
       p_input       IN  VARCHAR2
      ,p_max_length  IN  NUMBER DEFAULT 27
      ,p_method      IN  VARCHAR2 DEFAULT 'SUBSTR'
   ) RETURN VARCHAR2;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION tablespace_exists(
      p_tablespace_name IN VARCHAR2
   ) RETURN VARCHAR2;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_column_number(
       p_owner           IN VARCHAR2 DEFAULT NULL
      ,p_table_name      IN VARCHAR2
      ,p_column_name     IN VARCHAR2
   ) RETURN NUMBER;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_index_name(
       p_owner        IN  VARCHAR2 DEFAULT NULL
      ,p_table_name   IN  VARCHAR2
      ,p_column_name  IN  VARCHAR2
      ,p_suffix_ind   IN  VARCHAR2 DEFAULT 'I'
      ,p_full_suffix  IN  VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION index_exists(
       p_owner          IN  VARCHAR2 DEFAULT NULL
      ,p_index_name     IN  VARCHAR2
   ) RETURN VARCHAR2;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION index_exists(
       p_owner          IN  VARCHAR2 DEFAULT NULL
      ,p_table_name     IN  VARCHAR2
      ,p_column_name    IN  VARCHAR2
      ,p_index_type     IN  VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION table_exists(
       p_owner          IN  VARCHAR2 DEFAULT NULL
      ,p_table_name     IN  VARCHAR2
      ,p_column_name    IN  VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION mview_exists(
       p_owner            IN  VARCHAR2 DEFAULT NULL
      ,p_mview_name       IN  VARCHAR2
   ) RETURN VARCHAR2;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE get_spatial_index_name(
       p_owner            IN  VARCHAR2 DEFAULT NULL
      ,p_table_name       IN  VARCHAR2
      ,p_column_name      IN  VARCHAR2
      ,p_out_owner        OUT VARCHAR2
      ,p_out_index_name   OUT VARCHAR2
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE spatial_index_table(
       p_owner            IN  VARCHAR2 DEFAULT NULL
      ,p_table_name       IN  VARCHAR2
      ,p_column_name      IN  VARCHAR2
      ,p_out_owner        OUT VARCHAR2
      ,p_out_table_name   OUT VARCHAR2
   );

END dz_spidx_util;
/

GRANT EXECUTE ON dz_spidx_util TO PUBLIC;


--*************************--
PROMPT DZ_SPIDX_UTIL.pkb;

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


--*************************--
PROMPT DZ_SPIDX.tps;

CREATE OR REPLACE TYPE dz_spidx FORCE
AUTHID CURRENT_USER
AS OBJECT (
    index_status       VARCHAR2(255 Char)
   ,index_owner        VARCHAR2(30 Char)
   ,index_name         VARCHAR2(30 Char)
   ,table_owner        VARCHAR2(30 Char)
   ,table_name         VARCHAR2(30 Char)
   ,column_name        VARCHAR2(30 Char)
   ,index_parameters   VARCHAR2(1000 Char)
   ,geometry_dim_array MDSYS.SDO_DIM_ARRAY
   ,geometry_srid      NUMBER
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   ,CONSTRUCTOR FUNCTION dz_spidx
    RETURN SELF AS RESULT
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   ,CONSTRUCTOR FUNCTION dz_spidx(
        p_table_owner      IN  VARCHAR2 DEFAULT NULL
       ,p_table_name       IN  VARCHAR2
       ,p_column_name      IN  VARCHAR2
    ) RETURN SELF AS RESULT
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   ,CONSTRUCTOR FUNCTION dz_spidx(
        p_index_owner      IN  VARCHAR2 DEFAULT NULL
       ,p_index_name       IN  VARCHAR2
    ) RETURN SELF AS RESULT
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   ,MEMBER FUNCTION create_index(
      self            IN OUT dz_spidx
   ) RETURN VARCHAR2
    
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   ,MEMBER PROCEDURE create_index
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   ,MEMBER FUNCTION drop_index(
      self            IN OUT dz_spidx
   ) RETURN VARCHAR2
    
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   ,MEMBER PROCEDURE drop_index
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   ,MEMBER FUNCTION get_srid(
       self            IN OUT dz_spidx
    ) RETURN NUMBER
    
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   ,MEMBER PROCEDURE redefine_index(
        p_srid         IN  NUMBER
       ,p_keyword      IN  VARCHAR2 DEFAULT NULL
    )
    
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   ,MEMBER PROCEDURE change_table_srid(
       p_srid          IN  NUMBER
    )
    
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   ,MEMBER PROCEDURE harvest_index_metadata(
       self  IN OUT dz_spidx
    )
    
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   ,MEMBER PROCEDURE harvest_sdo_metadata(
       self  IN OUT dz_spidx
    )
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   ,MEMBER PROCEDURE harvest_sdo_srid(
       self  IN OUT dz_spidx
    )
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   ,MEMBER PROCEDURE drop_sdo_metadata
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   ,MEMBER PROCEDURE update_sdo_metadata(
       p_dim_array  IN  MDSYS.SDO_DIM_ARRAY DEFAULT NULL
      ,p_srid       IN  NUMBER DEFAULT NULL
    )
    
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   ,STATIC FUNCTION geodetic_XY_diminfo
    RETURN MDSYS.SDO_DIM_ARRAY
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   ,STATIC FUNCTION geodetic_XYZ_diminfo(
       p_z_lower_bound NUMBER DEFAULT -15000
      ,p_z_upper_bound NUMBER DEFAULT 15000
      ,p_z_tolerance   NUMBER DEFAULT 0.001
    ) RETURN MDSYS.SDO_DIM_ARRAY
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   ,STATIC FUNCTION geodetic_XYM_diminfo(
       p_m_lower_bound NUMBER DEFAULT 0
      ,p_m_upper_bound NUMBER DEFAULT 100
      ,p_m_tolerance   NUMBER DEFAULT 0.00001
   ) RETURN MDSYS.SDO_DIM_ARRAY
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   ,STATIC FUNCTION geodetic_XYZM_diminfo(
       p_z_lower_bound NUMBER DEFAULT -15000
      ,p_z_upper_bound NUMBER DEFAULT 15000
      ,p_z_tolerance   NUMBER DEFAULT 0.001
      ,p_m_lower_bound NUMBER DEFAULT 0
      ,p_m_upper_bound NUMBER DEFAULT 100
      ,p_m_tolerance   NUMBER DEFAULT 0.00001
   ) RETURN MDSYS.SDO_DIM_ARRAY
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   ,STATIC FUNCTION webmercator_XY_diminfo
    RETURN MDSYS.SDO_DIM_ARRAY
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   ,STATIC FUNCTION albers_XY_diminfo
    RETURN MDSYS.SDO_DIM_ARRAY
    
);
/

GRANT EXECUTE ON dz_spidx TO PUBLIC;


--*************************--
PROMPT DZ_SPIDX.tpb;

CREATE OR REPLACE TYPE BODY dz_spidx
AS

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   CONSTRUCTOR FUNCTION dz_spidx
   RETURN SELF AS RESULT
   AS
   BEGIN
      RETURN;
   
   END dz_spidx;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   CONSTRUCTOR FUNCTION dz_spidx(
       p_table_owner      IN  VARCHAR2 DEFAULT NULL
      ,p_table_name       IN  VARCHAR2
      ,p_column_name      IN  VARCHAR2
   ) RETURN SELF AS RESULT
   AS
   BEGIN
   
      --------------------------------------------------------------------------
      -- Step 10
      -- Grab the inputs
      --------------------------------------------------------------------------
      IF p_table_owner IS NULL
      THEN
         self.table_owner := USER;
         
      ELSE
         self.table_owner := p_table_owner;
         
      END IF;
      
      self.table_name     := p_table_name;
      self.column_name    := p_column_name;
      
      --------------------------------------------------------------------------
      -- Step 20
      -- Fetch the other information from the dictionary
      --------------------------------------------------------------------------
      self.harvest_sdo_metadata();
      self.harvest_index_metadata();
      
      IF self.geometry_srid IS NULL
      THEN
         self.harvest_sdo_srid();
         
      END IF;
             
      RETURN;
      
   END dz_spidx;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   CONSTRUCTOR FUNCTION dz_spidx(
       p_index_owner      IN  VARCHAR2 DEFAULT NULL
      ,p_index_name       IN  VARCHAR2
   ) RETURN SELF AS RESULT
   AS
   BEGIN
   
      --------------------------------------------------------------------------
      -- Step 10
      -- Grab the inputs
      --------------------------------------------------------------------------
      IF p_index_owner IS NULL
      THEN
         self.index_owner := USER;
         
      ELSE
         self.index_owner := p_index_owner;
         
      END IF;
      
      self.index_name := p_index_name;
      
      --------------------------------------------------------------------------
      -- Step 20
      -- Fetch the other information from the dictionary
      --------------------------------------------------------------------------
      self.harvest_index_metadata();
      
      IF self.table_name IS NOT NULL
      THEN
         self.harvest_sdo_metadata();
      
      END IF;
            
      RETURN;
      
   END dz_spidx;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   MEMBER FUNCTION create_index(
      self            IN OUT dz_spidx
   ) RETURN VARCHAR2
   AS
      str_sql         VARCHAR2(4000 Char);
      str_table_owner VARCHAR2(30 Char);
      str_index_owner VARCHAR2(30 Char);
      
   BEGIN
   
      --------------------------------------------------------------------------
      -- Step 10
      -- Check over object parameters
      --------------------------------------------------------------------------
      IF self.table_name IS NULL
      OR self.column_name IS NULL
      THEN
         RAISE_APPLICATION_ERROR(
             -20001
            ,'spatial index object not complete'
         );
      
      END IF;
      
      IF self.table_owner IS NULL
      THEN
         str_table_owner := USER;
      
      ELSE
         str_table_owner := self.table_owner;
      
      END IF;
      
      IF self.index_owner IS NULL
      THEN
         str_index_owner := USER;
      
      ELSE
         str_index_owner := self.index_owner;
      
      END IF;
      
      IF self.index_name IS NULL
      THEN
          self.index_name := SUBSTR(self.table_name,1,26) || '_SPX';
          
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 20
      -- Build the creation statement
      --------------------------------------------------------------------------
      str_sql := 'CREATE INDEX ' || str_index_owner || '.' || self.index_name || ' '
              || 'ON ' || str_table_owner || '.' || self.table_name || ' '
              || '(' || self.column_name || ') '
              || 'INDEXTYPE IS MDSYS.SPATIAL_INDEX ';
              
      --------------------------------------------------------------------------
      -- Step 30
      -- Add in optional parameters
      --------------------------------------------------------------------------        
      IF self.index_parameters IS NOT NULL
      THEN
         str_sql := str_sql || 'PARAMETERS(''' || self.index_parameters || ''') ';
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 40
      -- Return what we got
      --------------------------------------------------------------------------
      RETURN str_sql;         
     
   END create_index;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   MEMBER PROCEDURE create_index
   AS
   BEGIN
      EXECUTE IMMEDIATE self.create_index();
      
   EXCEPTION
      WHEN OTHERS
      THEN
         IF SQLCODE = -9999
         THEN
            NULL;
         
         ELSE
            RAISE;      
         
         END IF;
         
   END create_index;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   MEMBER FUNCTION drop_index(
      self            IN OUT dz_spidx
   ) RETURN VARCHAR2
   AS
      str_sql         VARCHAR2(4000 Char);
      str_index_owner VARCHAR2(30 Char);
      
   BEGIN
   
      --------------------------------------------------------------------------
      -- Step 10
      -- Check over object parameters
      --------------------------------------------------------------------------
      IF self.index_name IS NULL
      THEN
         RAISE_APPLICATION_ERROR(
             -20001
            ,'spatial index object not complete'
         );
         
      END IF;
      
      IF self.index_owner IS NULL
      THEN
         str_index_owner := USER;
         
      ELSE
         str_index_owner := self.index_owner;
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 20
      -- Build the drop statement
      --------------------------------------------------------------------------
      str_sql := 'DROP INDEX ' || str_index_owner || '.' || self.index_name || ' '
              || 'FORCE ';
              
      --------------------------------------------------------------------------
      -- Step 30
      -- Return what we got
      --------------------------------------------------------------------------
      RETURN str_sql;
   
   END drop_index;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   MEMBER PROCEDURE drop_index
   AS
   BEGIN
   
      IF self.index_name IS NULL
      THEN
         self.harvest_index_metadata();
         
         IF self.index_name IS NULL
         THEN
            RETURN;
         
         END IF;
         
      END IF;
      
      EXECUTE IMMEDIATE self.drop_index();
      
   EXCEPTION
      WHEN OTHERS
      THEN
         IF SQLCODE = -01418
         THEN
            NULL;
         
         ELSE
            RAISE;      
         
         END IF;
         
   END drop_index;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   MEMBER FUNCTION get_srid(
      self            IN OUT dz_spidx
   ) RETURN NUMBER
   AS
   BEGIN
      
      IF self.geometry_srid IS NULL
      THEN
         self.harvest_sdo_metadata();
      
         IF self.geometry_srid IS NULL
         THEN
             self.harvest_sdo_srid();
             
         END IF;
      
      END IF;
      
      RETURN self.geometry_srid;
      
   END get_srid;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   MEMBER PROCEDURE redefine_index(
       p_srid    IN  NUMBER
      ,p_keyword IN  VARCHAR2 DEFAULT NULL
   )
   AS
   BEGIN
   
      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      
      --------------------------------------------------------------------------
      -- Step 20
      -- Attempt to load metadata from precanned results
      --------------------------------------------------------------------------
      IF  p_srid IS NULL
      AND p_keyword = 'GEODETIC'
      THEN
         self.geometry_srid := NULL;
         self.geometry_dim_array := SDO_DIM_ARRAY(
             SDO_DIM_ELEMENT('Longitude',-180,180,0.0000005)
            ,SDO_DIM_ELEMENT('Latitude',-90,90,0.0000005)
         );
         
      ELSIF p_srid IN (8265,4269,8307,4326)
      AND (p_keyword IS NULL OR p_keyword IN ('XY'))
      THEN
         self.geometry_srid := p_srid;
         self.geometry_dim_array := dz_spidx.geodetic_XY_diminfo();
         
      ELSIF p_srid IN (8265,4269,8307,4326)
      AND (p_keyword IS NULL OR p_keyword IN ('XYM'))
      THEN
         self.geometry_srid := p_srid;
         self.geometry_dim_array := dz_spidx.geodetic_XYM_diminfo();
      
      ELSIF p_srid IN (3857)
      AND (p_keyword IS NULL OR p_keyword IN ('XY'))
      THEN
         self.geometry_srid := p_srid;
         self.geometry_dim_array := dz_spidx.webmercator_XY_diminfo();
         
      ELSIF p_srid BETWEEN 1000001 AND 1000005
      AND (p_keyword IS NULL OR p_keyword IN ('XY'))
      THEN
         self.geometry_srid := p_srid;
         self.geometry_dim_array := dz_spidx.albers_XY_diminfo();
   
      ELSE
         RAISE_APPLICATION_ERROR(
             -20001
            ,'srid has not be predefined in object'
         );
         
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 30
      -- Drop any existing spatial index
      --------------------------------------------------------------------------
      self.drop_index();
      
      --------------------------------------------------------------------------
      -- Step 40
      -- Redo the metadata
      --------------------------------------------------------------------------
      self.update_sdo_metadata();
      
      --------------------------------------------------------------------------
      -- Step 30
      -- Create the new spatial index
      --------------------------------------------------------------------------
      self.create_index();
   
   END redefine_index;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   MEMBER PROCEDURE change_table_srid(
      p_srid          IN  NUMBER
   )
   AS
      str_sql VARCHAR2(4000 Char);
      
   BEGIN
   
      self.drop_index();
   
      IF NVL(self.get_srid(),-99999) <> NVL(p_srid,-99999)
      THEN
         str_sql := 'UPDATE ' || self.table_owner || '.' || self.table_name || ' a '
                 || 'SET a.' || self.column_name || '.SDO_SRID = :p01 ';
              
         EXECUTE IMMEDIATE str_sql 
         USING p_srid;
      
         COMMIT;
         
      END IF;
   
   END change_table_srid;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   MEMBER PROCEDURE harvest_index_metadata(
      self  IN OUT dz_spidx
   ) 
   AS
      str_table_owner VARCHAR2(30 Char);
      str_index_owner VARCHAR2(30 Char);
      
   BEGIN
   
      IF self.table_owner IS NULL
      THEN
         str_table_owner := USER;
         
      ELSE
         str_table_owner := self.table_owner;
         
      END IF;
      
      IF self.index_owner IS NULL
      THEN
         str_index_owner := USER;
         
      ELSE
         str_index_owner := self.index_owner;
         
      END IF;
      
      IF self.table_name   IS NOT NULL
      AND self.column_name IS NOT NULL
      THEN
         SELECT
          a.table_owner
         ,a.owner
         ,a.index_name
         ,a.parameters
         INTO
          self.table_owner 
         ,self.index_owner
         ,self.index_name
         ,self.index_parameters
         FROM
         all_indexes a
         JOIN
         all_ind_columns b
         ON
             a.owner = b.index_owner
         AND a.index_name = b.index_name
         WHERE
             a.table_owner = str_table_owner
         AND a.table_name = self.table_name
         AND b.column_name = self.column_name;
         
         self.index_status := 'TRUE';
   
      ELSIF self.index_name IS NOT NULL
      THEN   
         SELECT
          a.table_owner
         ,a.table_name
         ,b.column_name
         ,a.owner
         ,a.parameters
         INTO 
          self.table_owner
         ,self.table_name
         ,self.column_name
         ,self.index_owner
         ,self.index_parameters
         FROM
         all_indexes a
         JOIN
         all_ind_columns b
         ON
         a.owner = b.index_owner AND
         a.index_name = b.index_name
         WHERE
         a.owner = str_index_owner AND
         a.index_name = self.index_name;
        
         self.index_status := 'TRUE';
   
      ELSE
         self.index_status := 'FALSE';
         
      END IF;
      
   EXCEPTION    
      WHEN NO_DATA_FOUND
      THEN
          self.index_status := 'FALSE';
      
      WHEN OTHERS
      THEN
         RAISE;
         
   END harvest_index_metadata;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   MEMBER PROCEDURE harvest_sdo_metadata(
      self  IN OUT dz_spidx
   )
   AS
      str_table_owner VARCHAR2(30 Char);
      
   BEGIN
   
      IF self.table_owner IS NULL
      THEN
         str_table_owner := USER;
         
      ELSE
         str_table_owner := self.table_owner;
         
      END IF;
   
      SELECT
       a.owner
      ,a.diminfo
      ,a.srid
      INTO
       self.table_owner
      ,self.geometry_dim_array
      ,self.geometry_srid
      FROM
      all_sdo_geom_metadata a
      WHERE
          a.owner = str_table_owner
      AND a.table_name = self.table_name
      AND a.column_name = self.column_name;
      
   EXCEPTION    
      WHEN NO_DATA_FOUND
      THEN
          self.index_status := 'FALSE';
      
      WHEN OTHERS
      THEN
         RAISE;
         
   END harvest_sdo_metadata;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   MEMBER PROCEDURE harvest_sdo_srid(
      self  IN OUT dz_spidx
   )
   AS
      str_sql VARCHAR2(4000 Char);
      
   BEGIN
   
      str_sql := 'SELECT '
              || 'a.' || self.column_name || '.SDO_SRID '
              || 'FROM '
              || self.table_owner || '.' || self.table_name || ' a '
              || 'WHERE '
              || 'rownum <= 1 ';
              
      EXECUTE IMMEDIATE str_sql 
      INTO self.geometry_srid;
      
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         NULL;
      WHEN OTHERS
      THEN
         RAISE;              
   
   END harvest_sdo_srid;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   MEMBER PROCEDURE drop_sdo_metadata
   AS
   BEGIN
   
      IF self.table_owner IS NULL
      OR self.table_owner = USER
      THEN
         DELETE FROM user_sdo_geom_metadata a
         WHERE
             a.table_name = self.table_name
         AND a.column_name = self.column_name;
      
      ELSE
         RAISE_APPLICATION_ERROR(
             -20001
            ,'not spatial table owner'
         );
         
      END IF;
      
      COMMIT;
      
   END drop_sdo_metadata;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   MEMBER PROCEDURE update_sdo_metadata(
      p_dim_array  IN  MDSYS.SDO_DIM_ARRAY DEFAULT NULL
     ,p_srid       IN  NUMBER DEFAULT NULL
   )
   AS
   BEGIN
   
      IF self.table_owner IS NULL
      OR self.table_owner = USER
      THEN
         self.drop_sdo_metadata();
         
         IF p_dim_array IS NOT NULL
         THEN
            self.geometry_dim_array := p_dim_array;
         
         END IF;
         
         IF p_srid IS NOT NULL
         THEN
            self.geometry_srid := p_srid;
            
         END IF;         
            
         INSERT INTO user_sdo_geom_metadata(
             table_name
            ,column_name
            ,diminfo
            ,srid
         ) VALUES (
             self.table_name
            ,self.column_name
            ,self.geometry_dim_array
            ,self.geometry_srid
         );
         
         COMMIT;
         
      ELSE
         RAISE_APPLICATION_ERROR(
             -20001
            ,'not spatial table owner'
         );
         
      END IF;
         
   END update_sdo_metadata;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   STATIC FUNCTION geodetic_XY_diminfo
   RETURN MDSYS.SDO_DIM_ARRAY
   AS
   BEGIN
      RETURN MDSYS.SDO_DIM_ARRAY(
          MDSYS.SDO_DIM_ELEMENT(
              'X'
             ,-180
             ,180
             ,0.05
          )
         ,MDSYS.SDO_DIM_ELEMENT(
              'Y'
             ,-90
             ,90
             ,0.05
          )
      );
      
   END geodetic_XY_diminfo;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   STATIC FUNCTION geodetic_XYZ_diminfo(
       p_z_lower_bound NUMBER DEFAULT -15000
      ,p_z_upper_bound NUMBER DEFAULT 15000
      ,p_z_tolerance   NUMBER DEFAULT 0.001
   ) RETURN MDSYS.SDO_DIM_ARRAY
   AS  
   BEGIN
      RETURN MDSYS.SDO_DIM_ARRAY(
          MDSYS.SDO_DIM_ELEMENT(
              'X'
             ,-180
             ,180
             ,.05
          )
         ,MDSYS.SDO_DIM_ELEMENT(
              'Y'
             ,-90
             ,90
             ,.05
          )
         ,MDSYS.SDO_DIM_ELEMENT(
              'Z'
             ,p_z_lower_bound
             ,p_z_upper_bound
             ,p_z_tolerance
          )
      );
      
   END geodetic_XYZ_diminfo;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   STATIC FUNCTION geodetic_XYM_diminfo(
       p_m_lower_bound NUMBER DEFAULT 0
      ,p_m_upper_bound NUMBER DEFAULT 100
      ,p_m_tolerance   NUMBER DEFAULT 0.00001
   ) RETURN MDSYS.SDO_DIM_ARRAY
   AS
   BEGIN
      RETURN MDSYS.SDO_DIM_ARRAY(
          MDSYS.SDO_DIM_ELEMENT(
              'X'
             ,-180
             ,180
             ,.05
          )
         ,MDSYS.SDO_DIM_ELEMENT(
              'Y'
             ,-90
             ,90
             ,.05
          )
         ,MDSYS.SDO_DIM_ELEMENT(
              'M'
             ,p_m_lower_bound
             ,p_m_upper_bound
             ,p_m_tolerance
          )
      );
      
   END geodetic_XYM_diminfo;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   STATIC FUNCTION geodetic_XYZM_diminfo(
       p_z_lower_bound NUMBER DEFAULT -15000
      ,p_z_upper_bound NUMBER DEFAULT 15000
      ,p_z_tolerance   NUMBER DEFAULT 0.001
      ,p_m_lower_bound NUMBER DEFAULT 0
      ,p_m_upper_bound NUMBER DEFAULT 100
      ,p_m_tolerance   NUMBER DEFAULT 0.00001
   ) RETURN MDSYS.SDO_DIM_ARRAY
   AS
   BEGIN
      RETURN MDSYS.SDO_DIM_ARRAY(
          MDSYS.SDO_DIM_ELEMENT(
              'X'
             ,-180
             ,180
             ,.05
          )
         ,MDSYS.SDO_DIM_ELEMENT(
              'Y'
             ,-90
             ,90
             ,.05
          )
         ,MDSYS.SDO_DIM_ELEMENT(
              'Z'
             ,p_z_lower_bound
             ,p_z_upper_bound
             ,p_z_tolerance
          )
         ,MDSYS.SDO_DIM_ELEMENT(
              'M'
             ,p_m_lower_bound
             ,p_m_upper_bound
             ,p_m_tolerance
          )
      );
      
   END geodetic_XYZM_diminfo;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   STATIC FUNCTION webmercator_XY_diminfo
   RETURN MDSYS.SDO_DIM_ARRAY
   AS
   BEGIN
      RETURN MDSYS.SDO_DIM_ARRAY(
          MDSYS.SDO_DIM_ELEMENT(
              'X'
             ,-20037508.34
             ,20037508.34
             ,0.05
          )
         ,MDSYS.SDO_DIM_ELEMENT(
              'Y'
             ,-20037508.34
             ,20037508.34
             ,0.05
          )
      );

   END webmercator_XY_diminfo;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   STATIC FUNCTION albers_XY_diminfo
   RETURN MDSYS.SDO_DIM_ARRAY
   AS
   BEGIN
      RETURN MDSYS.SDO_DIM_ARRAY(
          MDSYS.SDO_DIM_ELEMENT(
              'X'
             ,-999999999
             ,999999999
             ,0.05
          )
         ,MDSYS.SDO_DIM_ELEMENT(
              'Y'
             ,-999999999
             ,999999999
             ,0.05
          )
      );

   END albers_XY_diminfo;

END;
/


--*************************--
PROMPT DZ_SPIDX_LIST.tps;

CREATE OR REPLACE TYPE dz_spidx_list                                          
AS 
TABLE OF dz_spidx;
/

GRANT EXECUTE ON dz_spidx_list TO PUBLIC;


--*************************--
PROMPT DZ_SPIDX_MAIN.pks;

CREATE OR REPLACE PACKAGE dz_spidx_main
AUTHID CURRENT_USER
AS
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   header: DZ_SPIDX
     
   - Build ID: 4
   - TFS Change Set: 8291
   
   Utilities for the management of Oracle MDSYS.SPATIAL_INDEX domain indexes
   
   */
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   Function: dz_spidz_main.geodetic_XY_diminfo

   Function to quickly return a "default" geodetic dimensional info array.

   Parameters:

      None
      
   Returns:

      MDSYS.SDO_DIM_ARRAY collection
      
   Notes:
   
   - Assumes 5 centimeter tolerance for all geodetic spatial information. 

   */
   FUNCTION geodetic_XY_diminfo
   RETURN MDSYS.SDO_DIM_ARRAY;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   Function: dz_spidz_main.geodetic_XYZ_diminfo

   Function to quickly return a "default" 3D geodetic dimensional info array.

   Parameters:

      p_z_lower_bound - optional override for lower Z bound (default -15000)
      p_z_upper_bound - optional override for upper Z bound (default 15000)
      p_z_tolerance   - optional override for Z tolerance (default 0.001 units)
      
   Returns:

      MDSYS.SDO_DIM_ARRAY collection
      
   Notes:
   
   - Assumes 5 centimeter tolerance for all geodetic spatial information. 

   */
   FUNCTION geodetic_XYZ_diminfo(
       p_z_lower_bound NUMBER DEFAULT -15000
      ,p_z_upper_bound NUMBER DEFAULT 15000
      ,p_z_tolerance   NUMBER DEFAULT 0.001
   ) RETURN MDSYS.SDO_DIM_ARRAY;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   Function: dz_spidz_main.geodetic_XYM_diminfo

   Function to quickly return a "default" LRS geodetic dimensional info array.

   Parameters:

      p_m_lower_bound - optional override for lower M bound (default 0)
      p_m_upper_bound - optional override for upper M bound (default 100)
      p_m_tolerance   - optional override for M tolerance (default 0.00001 units)
      
   Returns:

      MDSYS.SDO_DIM_ARRAY collection
      
   Notes:
   
   - Assumes 5 centimeter tolerance for all geodetic spatial information. 
   
   - M defaults represent common reach measure system used in the US National
     hydrology dataset.

   */
   FUNCTION geodetic_XYM_diminfo(
       p_m_lower_bound NUMBER DEFAULT 0
      ,p_m_upper_bound NUMBER DEFAULT 100
      ,p_m_tolerance   NUMBER DEFAULT 0.00001
   ) RETURN MDSYS.SDO_DIM_ARRAY;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   Function: dz_spidz_main.geodetic_XYZM_diminfo

   Function to quickly return a "default" 3D LRS geodetic dimensional info array.

   Parameters:

      p_z_lower_bound - optional override for lower Z bound (default -15000)
      p_z_upper_bound - optional override for upper Z bound (default 15000)
      p_z_tolerance   - optional override for Z tolerance (default 0.001 units)
      p_m_lower_bound - optional override for lower M bound (default 0)
      p_m_upper_bound - optional override for upper M bound (default 100)
      p_m_tolerance   - optional override for M tolerance (default 0.00001 units)
      
   Returns:

      MDSYS.SDO_DIM_ARRAY collection
      
   Notes:
   
   - Assumes 5 centimeter tolerance for all geodetic spatial information. 
   
   - M defaults represent common reach measure system used in the US National
     hydrology dataset.

   */
   FUNCTION geodetic_XYZM_diminfo(
       p_z_lower_bound NUMBER DEFAULT -15000
      ,p_z_upper_bound NUMBER DEFAULT 15000
      ,p_z_tolerance   NUMBER DEFAULT 0.001
      ,p_m_lower_bound NUMBER DEFAULT 0
      ,p_m_upper_bound NUMBER DEFAULT 100
      ,p_m_tolerance   NUMBER DEFAULT 0.00001
   ) RETURN MDSYS.SDO_DIM_ARRAY;
   
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
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   Function: dz_spidz_main.get_spatial_indexes

   Function to harvest into list of dz_spidx objects all spatial indexes on a
   given table.

   Parameters:

      p_owner      optional owner name of table to be inspected
      p_table_name table to be inspects for spatial indexes
      
   Returns:

      dz_spidx_list collection
      
   Notes:
   
   - The list of dz_spidx will have a count of zero if no spatial indexes are 
     discovered.

   */
   FUNCTION get_spatial_indexes(
       p_owner      IN  VARCHAR2 DEFAULT NULL
      ,p_table_name IN  VARCHAR2
   ) RETURN dz_spidx_list;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE flush_spatial_indexes(
       p_owner      IN  VARCHAR2 DEFAULT NULL
      ,p_table_name IN  VARCHAR2
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE flush_spatial_indexes(
       p_owner      IN  VARCHAR2 DEFAULT NULL
      ,p_table_name IN  VARCHAR2
      ,p_output     OUT MDSYS.SDO_STRING2_ARRAY
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   Function: dz_spidz_main.flush_spatial_indexes

   Function to harvest into list of dz_spidx objects all spatial indexes on a
   given table and subsequently drop those indexes.

   Parameters:

      p_owner      optional owner name of table to be inspected
      p_table_name table to be inspects for spatial indexes
      
   Returns:

      dz_spidx_list collection
      
   Notes:
   
   - Obviously the user must have permission to drop the indexes for this function
     to succeed.
     
   - The list of dz_spidx will have a count of zero if no spatial indexes are 
     discovered.

   */
   FUNCTION flush_spatial_indexes(
       p_owner      IN  VARCHAR2 DEFAULT NULL
      ,p_table_name IN  VARCHAR2
   ) RETURN dz_spidx_list;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   Procedure: dz_spidz_main.recreate_spatial_indexes

   Procedure to recreate all spatial indexes documented in the collection of 
   dz_spidx objects.

   Parameters:

      p_index_array - dz_spidx_list collection of dz_spidx objects
      
   Returns:

      Nothing
      
   Notes:
   
   - Obviously the user must have permission to create the indexes for this 
     function to succeed.

   */
   PROCEDURE recreate_spatial_indexes(
      p_index_array         IN  dz_spidx_list
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   Procedure: dz_spidz_main.recreate_spatial_indexes

   Rebuilding spatial domain indexes using index rebuild DDL may be problematic
   for a number of reasons.  For example an online rebuild will require the 
   spatial index exist twice on disk until the final swap removes the old version.
   This can create storage management problems for very large indexes.  Often 
   the simple solution is to just drop and recreate the index.  This procedure
   wraps together the step for this task using dz_spidx to persist the details
   of the spatial index so you do not have to.

   Parameters:

      p_filter - use to limit the spatial rebuilds to a given set of tables.  The
      filter is simply table names LIKE '%' || p_filter || '%'
      p_tablespace - optional parameter to change the domain index tablespace used.
      p_quiet - optional TRUE or FALSE parameter to log details of rebuild action
      to DBMS_OUTPUT.
      
   Returns:

      Nothing
      
   Notes:
   
   - Note that details of the spatial index are not stored anywhere permanently
     during the rebuild process.  If for some reason your rebuild fails (space 
     issues perhaps), the details of the spatial index are lost and you will 
     need to recreate the index from your own DDL documentation.

   */
   PROCEDURE rebuild_user_spatial(
       p_filter              IN  VARCHAR2
      ,p_tablespace          IN  VARCHAR2 DEFAULT NULL
      ,p_quiet               IN  VARCHAR2 DEFAULT 'FALSE'
   );

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   Procedure: dz_spidz_main.spatial_mview_refresh

   Refreshing an Oracle materialized view with a spatial domain index may
   generate punishing performance problems.  Usually there is little to be done
   other than drop the spatial index, refresh the materialized view and then 
   recreate the index afterwards.  The following procedure inspects a given
   materialized view, collects information on the spatial indexes, drop those 
   spatial indexes, executes the refresh and then replaces the spatial indexes.

   Parameters:

      list - materialized view refresh parameters
      method - materialized view refresh parameters
      rollback_seg - materialized view refresh parameters
      push_deferred_rpc - materialized view refresh parameters
      refresh_after_errors - materialized view refresh parameters
      purge_option - materialized view refresh parameters
      parallelism - materialized view refresh parameters
      heap_size - materialized view refresh parameters
      atomic_refresh - materialized view refresh parameters
      nested - materialized view refresh parameters
      
   Returns:

      Nothing
      
   Notes:
   
   - For information on the procedure parameters see Oracle documentation on
     DBMS_MVIEW.REFRESH.
     
   - DZ_SPIDX currently has no functionality to persist the details of a given
     spatial index outside the scope of it's current process.  If your materialized
     view refresh crashes for some reason, the information about the dropped
     spatial index is lost and will need to be recreated from your DDL documentation.

   */
   PROCEDURE spatial_mview_refresh(
       list                 IN  VARCHAR2
      ,method               IN  VARCHAR2       := NULL
      ,rollback_seg         IN  VARCHAR2       := NULL
      ,push_deferred_rpc    IN  BOOLEAN        := TRUE
      ,refresh_after_errors IN  BOOLEAN        := FALSE
      ,purge_option         IN  BINARY_INTEGER := 1
      ,parallelism          IN  BINARY_INTEGER := 0
      ,heap_size            IN  BINARY_INTEGER := 0
      ,atomic_refresh       IN  BOOLEAN        := TRUE
      ,nested               IN  BOOLEAN        := FALSE
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE sdo_join_check(
       p_table_name1        IN  VARCHAR2
      ,p_column_name1       IN  VARCHAR2
      ,p_table_name2        IN  VARCHAR2
      ,p_column_name2       IN  VARCHAR2
      ,p_return_code        OUT NUMBER
      ,p_status_message     OUT VARCHAR2
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   Function: dz_spidz_main.sdo_join_check

   Utilizing SDO_JOIN in cross-schema fashion is highly problematic as often the
   outsider schema lacks privledges on the domain index tables needed to utilize
   SDO_JOIN.  Even when the permissions are granted, the next time the spatial
   index is rebuilt the problem will reoccur.  Similarly a missing spatial index
   will equally hose the spatial join.  This function return TRUE or FALSE 
   regarding whether SDO_JOIN is currently possible between two tables.

   Parameters:

      p_table_name1  - [owner.]table_name of first table in join
      p_column_name1 - column name of first table in join
      p_table_name2  - [owner.]table_name of second table in join
      p_column_name2 - column name of second table in join
      
   Returns:

      VARCHAR2 text of either TRUE or FALSE
      
   Notes:
   
   - For information on the actual problem use the sdo_join_check_verbose 
     version.

   */
   FUNCTION sdo_join_check(
       p_table_name1        IN  VARCHAR2
      ,p_column_name1       IN  VARCHAR2
      ,p_table_name2        IN  VARCHAR2
      ,p_column_name2       IN  VARCHAR2
   ) RETURN VARCHAR2;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   Function: dz_spidz_main.sdo_join_check_verbose

   Utilizing SDO_JOIN in cross-schema fashion is highly problematic as often the
   outsider schema lacks privledges on the domain index tables needed to utilize
   SDO_JOIN.  Even when the permissions are granted, the next time the spatial
   index is rebuilt the problem will reoccur.  Similarly a missing spatial index
   will equally hose the spatial join.  This function return details on what
   actions or permissions are needed in order to execute a spatial join between
   two tables.

   Parameters:

      p_table_name1  - [owner.]table_name of first table in join
      p_column_name1 - column name of first table in join
      p_table_name2  - [owner.]table_name of second table in join
      p_column_name2 - column name of second table in join
      
   Returns:

      VARCHAR2 text or either TRUE or an explanation of the current problem
      
   Notes:
   
   - This functions assumes the basics that you can see the tables in question
     and thus interrogate table metadata to discover the names of the domain
     index tables.  The main results will be the exact domain table name that
     you need granted select permission upon to accomplish the spatial join.

   */
   FUNCTION sdo_join_check_verbose(
       p_table_name1        IN  VARCHAR2
      ,p_column_name1       IN  VARCHAR2
      ,p_table_name2        IN  VARCHAR2
      ,p_column_name2       IN  VARCHAR2
   ) RETURN VARCHAR2;
   
END dz_spidx_main;
/

GRANT EXECUTE ON dz_spidx_main TO public;


--*************************--
PROMPT DZ_SPIDX_MAIN.pkb;

CREATE OR REPLACE PACKAGE BODY dz_spidx_main
AS

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION geodetic_XY_diminfo
   RETURN MDSYS.SDO_DIM_ARRAY
   AS
   BEGIN
      RETURN dz_spidx.geodetic_XY_diminfo();
      
   END geodetic_XY_diminfo;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION geodetic_XYZ_diminfo(
       p_z_lower_bound NUMBER DEFAULT -15000
      ,p_z_upper_bound NUMBER DEFAULT 15000
      ,p_z_tolerance   NUMBER DEFAULT 0.001
   ) RETURN MDSYS.SDO_DIM_ARRAY
   AS  
   BEGIN
      RETURN dz_spidx.geodetic_XYZ_diminfo(
          p_z_lower_bound => p_z_lower_bound
         ,p_z_upper_bound => p_z_upper_bound
         ,p_z_tolerance   => p_z_tolerance
      );
      
   END geodetic_XYZ_diminfo;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION geodetic_XYM_diminfo(
       p_m_lower_bound NUMBER DEFAULT 0
      ,p_m_upper_bound NUMBER DEFAULT 100
      ,p_m_tolerance   NUMBER DEFAULT 0.00001
   ) RETURN MDSYS.SDO_DIM_ARRAY
   AS
   BEGIN
      RETURN dz_spidx.geodetic_XYM_diminfo(
          p_m_lower_bound => p_m_lower_bound
         ,p_m_upper_bound => p_m_upper_bound
         ,p_m_tolerance   => p_m_tolerance
      );
      
   END geodetic_XYM_diminfo;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION geodetic_XYZM_diminfo(
       p_z_lower_bound NUMBER DEFAULT -15000
      ,p_z_upper_bound NUMBER DEFAULT 15000
      ,p_z_tolerance   NUMBER DEFAULT 0.001
      ,p_m_lower_bound NUMBER DEFAULT 0
      ,p_m_upper_bound NUMBER DEFAULT 100
      ,p_m_tolerance   NUMBER DEFAULT 0.00001
   ) RETURN MDSYS.SDO_DIM_ARRAY
   AS
   BEGIN
      RETURN dz_spidx.geodetic_XYZM_diminfo(
          p_z_lower_bound => p_z_lower_bound
         ,p_z_upper_bound => p_z_upper_bound
         ,p_z_tolerance   => p_z_tolerance
         ,p_m_lower_bound => p_m_lower_bound
         ,p_m_upper_bound => p_m_upper_bound
         ,p_m_tolerance   => p_m_tolerance
      );
      
   END geodetic_XYZM_diminfo;

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
      DBMS_MVIEW.REFRESH(
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
      str_owner       VARCHAR2(30 Char) := UPPER(p_owner);
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
      str_owner       VARCHAR2(30 Char) := UPPER(p_owner);
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
      str_owner  VARCHAR2(30 Char) := UPPER(p_owner);
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
      str_owner VARCHAR2(30 Char) := UPPER(p_owner);
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
      str_filter     VARCHAR2(4000 Char) := UPPER(p_filter);
      str_quiet      VARCHAR2(4000 Char) := UPPER(p_quiet);
      ary_tables     MDSYS.SDO_STRING2_ARRAY;
      ary_columns    MDSYS.SDO_STRING2_ARRAY;
      ary_colnums    MDSYS.SDO_NUMBER_ARRAY;
      ary_indexes    MDSYS.SDO_STRING2_ARRAY;
      str_tablespace_blurb VARCHAR2(4000 Char);
      str_indexname  VARCHAR2(30 Char);
      str_sql        VARCHAR2(4000 Char);
      
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
      str_owner1        VARCHAR2(30 Char);
      str_table1        VARCHAR2(30 Char);
      str_owner2        VARCHAR2(30 Char);
      str_table2        VARCHAR2(30 Char);
      num_counter1      PLS_INTEGER;
      num_counter2      PLS_INTEGER;
      str_spidx_owner1  VARCHAR2(30 Char);
      str_spidx_table1  VARCHAR2(30 Char);
      str_spidx_owner2  VARCHAR2(30 Char);
      str_spidx_table2  VARCHAR2(30 Char);
      
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
      str_status_message VARCHAR2(4000 Char);
      
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
      str_status_message VARCHAR2(4000 Char);
      
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


--*************************--
PROMPT DZ_SPIDX_TEST.pks;

CREATE OR REPLACE PACKAGE dz_spidx_test
AUTHID DEFINER
AS

   C_TFS_CHANGESET CONSTANT NUMBER := 8291;
   C_JENKINS_JOBNM CONSTANT VARCHAR2(255 Char) := 'NULL';
   C_JENKINS_BUILD CONSTANT NUMBER := 4;
   C_JENKINS_BLDID CONSTANT VARCHAR2(255 Char) := 'NULL';
   
   C_PREREQUISITES CONSTANT MDSYS.SDO_STRING2_ARRAY := MDSYS.SDO_STRING2_ARRAY(
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION prerequisites
   RETURN NUMBER;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION version
   RETURN VARCHAR2;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION inmemory_test
   RETURN NUMBER;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION scratch_test
   RETURN NUMBER;
      
END dz_spidx_test;
/

GRANT EXECUTE ON dz_spidx_test TO public;


--*************************--
PROMPT DZ_SPIDX_TEST.pkb;

CREATE OR REPLACE PACKAGE BODY dz_spidx_test
AS

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION prerequisites
   RETURN NUMBER
   AS
      num_check NUMBER;
      
   BEGIN
      
      FOR i IN 1 .. C_PREREQUISITES.COUNT
      LOOP
         SELECT 
         COUNT(*)
         INTO num_check
         FROM 
         user_objects a
         WHERE 
             a.object_name = C_PREREQUISITES(i) || '_TEST'
         AND a.object_type = 'PACKAGE';
         
         IF num_check <> 1
         THEN
            RETURN 1;
         
         END IF;
      
      END LOOP;
      
      RETURN 0;
   
   END prerequisites;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION version
   RETURN VARCHAR2
   AS
   BEGIN
      RETURN '{"TFS":' || C_TFS_CHANGESET || ','
      || '"JOBN":"' || C_JENKINS_JOBNM || '",'   
      || '"BUILD":' || C_JENKINS_BUILD || ','
      || '"BUILDID":"' || C_JENKINS_BLDID || '"}';
      
   END version;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION inmemory_test
   RETURN NUMBER
   AS
   BEGIN
      RETURN 0;
      
   END inmemory_test;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION scratch_test
   RETURN NUMBER
   AS
   BEGIN
      RETURN 0;
      
   END scratch_test;

END dz_spidx_test;
/


--*************************--
PROMPT sqlplus_footer.sql;


SHOW ERROR;

DECLARE
   l_num_errors PLS_INTEGER;

BEGIN

   SELECT
   COUNT(*)
   INTO l_num_errors
   FROM
   user_errors a
   WHERE
   a.name LIKE 'DZ_SPIDX%';

   IF l_num_errors <> 0
   THEN
      RAISE_APPLICATION_ERROR(-20001,'COMPILE ERROR');

   END IF;

   l_num_errors := DZ_SPIDX_TEST.inmemory_test();

   IF l_num_errors <> 0
   THEN
      RAISE_APPLICATION_ERROR(-20001,'INMEMORY TEST ERROR');

   END IF;

END;
/

EXIT;


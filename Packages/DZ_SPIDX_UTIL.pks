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


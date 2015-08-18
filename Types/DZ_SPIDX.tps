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
   
);
/

GRANT EXECUTE ON dz_spidx TO PUBLIC;


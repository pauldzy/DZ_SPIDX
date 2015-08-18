CREATE OR REPLACE PACKAGE dz_spidx_main
AUTHID CURRENT_USER
AS
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   header: DZ_SPIDX
     
   - Build ID: DZBUILDIDDZ
   - TFS Change Set: DZTFSCHANGESETDZ
   
   Utilities for the management of Oracle MDSYS.SPATIAL_INDEX domain indexes
   
   */
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_XY_diminfo
   RETURN MDSYS.SDO_DIM_ARRAY;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_XYZ_diminfo
   RETURN MDSYS.SDO_DIM_ARRAY;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_XYM_diminfo
   RETURN MDSYS.SDO_DIM_ARRAY;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_XYZM_diminfo
   RETURN MDSYS.SDO_DIM_ARRAY;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_XYMZ_diminfo
   RETURN MDSYS.SDO_DIM_ARRAY;
   
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
   FUNCTION flush_spatial_indexes(
       p_owner      IN  VARCHAR2 DEFAULT NULL
      ,p_table_name IN  VARCHAR2
   ) RETURN dz_spidx_list;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE recreate_spatial_indexes(
      p_index_array         IN  dz_spidx_list
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE rebuild_user_spatial(
       p_filter              IN  VARCHAR2
      ,p_tablespace          IN  VARCHAR2 DEFAULT NULL
      ,p_quiet               IN  VARCHAR2 DEFAULT 'FALSE'
   );

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
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
   FUNCTION sdo_join_check(
       p_table_name1        IN  VARCHAR2
      ,p_column_name1       IN  VARCHAR2
      ,p_table_name2        IN  VARCHAR2
      ,p_column_name2       IN  VARCHAR2
   ) RETURN VARCHAR2;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION sdo_join_check_verbose(
       p_table_name1        IN  VARCHAR2
      ,p_column_name1       IN  VARCHAR2
      ,p_table_name2        IN  VARCHAR2
      ,p_column_name2       IN  VARCHAR2
   ) RETURN VARCHAR2;
   
END dz_spidx_main;
/

GRANT EXECUTE ON dz_spidx_main TO public;


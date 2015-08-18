CREATE OR REPLACE PACKAGE dz_dict_main
AUTHID CURRENT_USER
AS
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   header: DZ_DICT
     
   - Build ID: DZBUILDIDDZ
   - TFS Change Set: DZTFSCHANGESETDZ
   
   Utilities for the manipulation of the Oracle data dictionary.
   
   */
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE drop_type_quietly(
       p_owner            IN  VARCHAR2 DEFAULT NULL
      ,p_type_name        IN  VARCHAR2
   );

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE drop_table_quietly (
       p_owner            IN  VARCHAR2 DEFAULT NULL
      ,p_table_name       IN  VARCHAR2
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION table_exists(
       p_owner            IN  VARCHAR2 DEFAULT NULL
      ,p_table_name       IN  VARCHAR2
      ,p_column_name      IN  VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION table_exists(
       p_owner            IN  VARCHAR2 DEFAULT NULL
      ,p_table_name       IN  VARCHAR2
      ,p_column_name      IN  MDSYS.SDO_STRING2_ARRAY
   ) RETURN VARCHAR2;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION tables_exists(
       p_owner            IN  VARCHAR2 DEFAULT NULL
      ,p_table_names      IN  MDSYS.SDO_STRING2_ARRAY
   ) RETURN VARCHAR2;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION mview_exists(
       p_owner            IN  VARCHAR2 DEFAULT NULL
      ,p_mview_name       IN  VARCHAR2
   ) RETURN VARCHAR2;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION tablespace_exists(
      p_tablespace_name   IN  VARCHAR2
   ) RETURN VARCHAR2;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION table_privileges(
       p_owner            IN  VARCHAR2 DEFAULT NULL
      ,p_table_name       IN  VARCHAR2
   ) RETURN MDSYS.SDO_STRING2_ARRAY;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION table_privileges_dml(
       p_owner            IN  VARCHAR2 DEFAULT NULL
      ,p_table_name       IN  VARCHAR2
   ) RETURN VARCHAR2;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION sequence_exists(
       p_owner            IN  VARCHAR2 DEFAULT NULL
      ,p_sequence_name    IN  VARCHAR2
   ) RETURN VARCHAR2;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE drop_sequence(
       p_owner            IN  VARCHAR2 DEFAULT NULL
      ,p_sequence_name    IN  VARCHAR2
      ,p_like_flag        IN  VARCHAR2 DEFAULT 'FALSE'
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE sequence_from_max_column(
       p_owner            IN  VARCHAR2 DEFAULT NULL
      ,p_table_name       IN  VARCHAR2
      ,p_column_name      IN  VARCHAR2
      ,p_sequence_owner   IN  VARCHAR2 DEFAULT NULL
      ,p_sequence_name    IN OUT VARCHAR2
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION quick_sequence(
       p_owner           IN  VARCHAR2 DEFAULT NULL
      ,p_start_with      IN  NUMBER   DEFAULT 1
      ,p_prefix          IN  VARCHAR2 DEFAULT NULL
      ,p_suffix          IN  VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION object_exists(
       p_owner            IN  VARCHAR2 DEFAULT NULL
      ,p_object_type_name IN  VARCHAR2
   ) RETURN VARCHAR2;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION object_is_valid(
       p_owner            IN  VARCHAR2 DEFAULT NULL
      ,p_object_type_name IN  VARCHAR2
   ) RETURN VARCHAR2;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_column_number(
       p_owner            IN  VARCHAR2 DEFAULT NULL
      ,p_table_name       IN  VARCHAR2
      ,p_column_name      IN  VARCHAR2
   ) RETURN NUMBER;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION rename_to_x(
       p_owner            IN  VARCHAR2 DEFAULT NULL
      ,p_table_name       IN  VARCHAR2
      ,p_flush_objects    IN  VARCHAR2 DEFAULT 'FALSE'
   ) RETURN VARCHAR2;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE fast_not_null(
       p_owner            IN  VARCHAR2 DEFAULT NULL
      ,p_table_name       IN  VARCHAR2
      ,p_column_name      IN  VARCHAR2
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE drop_indexes(
       p_owner            IN  VARCHAR2 DEFAULT NULL
      ,p_table_name       IN  VARCHAR2
   );

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE drop_index(
       p_owner            IN  VARCHAR2 DEFAULT NULL
      ,p_index_name       IN  VARCHAR2
      ,p_like_flag        IN  VARCHAR2 DEFAULT 'FALSE'
   );

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION index_exists(
       p_owner            IN  VARCHAR2 DEFAULT NULL
      ,p_index_name       IN  VARCHAR2
   ) RETURN VARCHAR2;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE drop_constraints(
       p_owner            IN  VARCHAR2 DEFAULT NULL
      ,p_table_name       IN  VARCHAR2
   );
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE drop_constraint(
       p_owner            IN  VARCHAR2 DEFAULT NULL
      ,p_constraint_name  IN  VARCHAR2
      ,p_like_flag        IN  VARCHAR2 DEFAULT 'FALSE'
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE drop_ref_constraints(
       p_owner            IN  VARCHAR2 DEFAULT NULL
      ,p_table_name       IN  VARCHAR2
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE get_index_name(
       p_owner             IN  VARCHAR2 DEFAULT NULL
      ,p_table_name        IN  VARCHAR2
      ,p_column_name       IN  VARCHAR2
      ,p_index_owner       OUT VARCHAR2
      ,p_index_name        OUT VARCHAR2
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION new_index_name(
       p_owner             IN  VARCHAR2 DEFAULT NULL
      ,p_table_name        IN  VARCHAR2
      ,p_column_name       IN  VARCHAR2
      ,p_suffix_ind        IN  VARCHAR2 DEFAULT 'I'
      ,p_full_suffix       IN  VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE fast_index(
       p_owner             IN  VARCHAR2 DEFAULT NULL
      ,p_table_name        IN  VARCHAR2
      ,p_column_name       IN  VARCHAR2
      ,p_index_type        IN  VARCHAR2 DEFAULT NULL
      ,p_tablespace        IN  VARCHAR2 DEFAULT NULL
      ,p_logging           IN  VARCHAR2 DEFAULT 'TRUE'
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION table_index_ddl(
       p_owner             IN  VARCHAR2 DEFAULT NULL
      ,p_table_name        IN  VARCHAR2
   ) RETURN MDSYS.SDO_STRING2_ARRAY;
   
END dz_dict_main;
/

GRANT EXECUTE ON dz_dict_main TO public;


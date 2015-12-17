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


import { use, useEffect, useMemo, useRef, useCallback } from "react";
import { useQuery } from "@apollo/client";
import { useQueriesStore, QueryKey } from "./useQueryStore";
import { AdventurerQuery, BattleQuery, ItemQuery } from "./graphql/types";

type Variables = Record<
  string,
  string | number | number[] | boolean | null | undefined | Date
>;

// type Queries = | AdventurerQuery | BattleQuery

const useCustomQuery = (
  queryKey: QueryKey,
  query: any,
  variables?: Variables,
  skip?: boolean
) => {
  const { updateData } = useQueriesStore();

  const { data, loading, refetch } = useQuery(query, {
    variables: variables,
    skip: skip,
  });

  const refetchWrapper = useCallback(async () => {
    try {
      await refetch();
    } catch (error) {
      console.error("Error refetching:", error);
      throw error;
    }
  }, [refetch]);

  useEffect(() => {
    if (data) {
      updateData(queryKey, data, loading, refetchWrapper);
    }
  }, []);
};

export default useCustomQuery;

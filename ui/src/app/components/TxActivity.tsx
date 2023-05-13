"use client";
import { useEffect, useState } from "react";
import { useWaitForTransaction } from "@starknet-react/core";
import { displayAddress, padAddress } from "../lib/utils";
import { useQueriesStore } from "../hooks/useQueryStore";
import useLoadingStore from "../hooks/useLoadingStore";
import LootIconLoader from "./Loader";
import useAdventurerStore from "../hooks/useAdventurerStore";

export interface TxActivityProps {
  hash: string | undefined;
}

export const TxActivity = () => {
  const notificationData = useLoadingStore((state) => state.notificationData);
  const loadingQuery = useLoadingStore((state) => state.loadingQuery);
  const stopLoading = useLoadingStore((state) => state.stopLoading);
  const loading = useLoadingStore((state) => state.loading);
  const hash = useLoadingStore((state) => state.hash);
  const pendingMessage = useLoadingStore((state) => state.pendingMessage);
  const type = useLoadingStore((state) => state.type);
  const loadingAdventurer = useLoadingStore((state) => state.adventurer);
  const adventurer = useAdventurerStore((state) => state.adventurer);
  const {
    data: queryData,
    isDataUpdated,
    refetch,
    resetDataUpdated,
  } = useQueriesStore();
  const [accepted, setAccepted] = useState(false);
  const { data } = useWaitForTransaction({
    hash,
    watch: true,
    onAcceptedOnL2: () => {
      setAccepted(true);
    },
  });

  console.log(
    loadingQuery,
    queryData.discoveryByTxHashQuery?.discoveries[0],
    loadingQuery && isDataUpdated[loadingQuery],
    loading
  );

  useEffect(() => {
    // Check if loading, loadingQuery, and isDataUpdated are truthy
    if (accepted && hash && loadingQuery && isDataUpdated[loadingQuery]) {
      // Handle "Attack" or "Flee" types
      if (type === "Attack" || type === "Flee") {
        if (queryData?.battlesByTxHashQuery) {
          stopLoading({
            data: queryData.battlesByTxHashQuery.battles,
            beast: notificationData.beast,
          });
        }
        setAccepted(false);
        resetDataUpdated(loadingQuery);
      }

      // Handle "Explore" type
      else if (type === "Explore") {
        stopLoading(queryData.discoveryByTxHashQuery.discoveries[0]);
        setAccepted(false);
        resetDataUpdated(loadingQuery);
      }

      // Handle other types
      else {
        stopLoading(notificationData);
        setAccepted(false);
        resetDataUpdated(loadingQuery);
      }
    }
  }, [loadingQuery && isDataUpdated[loadingQuery], accepted, hash]);

  return (
    <>
      {type != "Multicall" && type != "Create" ? (
        loading && hash && loadingAdventurer === adventurer?.id ? (
          <div className="flex flex-row items-center gap-5">
            {data?.status == "RECEIVED" || data?.status == "PENDING" ? (
              <div className="flex w-48 loading-ellipsis ">
                <LootIconLoader className="mr-3" />
                {pendingMessage}
              </div>
            ) : (
              <div className="loading-ellipsis">Refreshing data</div>
            )}
            <div className="flex flex-row gap-2">
              Hash:{" "}
              <a
                href={`https://testnet.starkscan.co/tx/${padAddress(hash)}`}
                target="_blank"
                className="animate-pulse"
              >
                {displayAddress(hash)}
              </a>
            </div>
            {data && <div>Status: {data.status}</div>}
          </div>
        ) : null
      ) : (
        (data?.status == "RECEIVED" || data?.status == "PENDING") && (
          <div className="flex flex-row items-center gap-5">
            <div className="flex w-48 loading-ellipsis">
              <LootIconLoader className="self-center mr-3" />
              {pendingMessage}
            </div>
            <div className="flex flex-row gap-2">
              Hash:{" "}
              <a
                href={`https://testnet.starkscan.co/tx/${padAddress(hash)}`}
                target="_blank"
                className="animate-pulse"
              >
                {displayAddress(hash)}
              </a>
            </div>
            {data && <div>Status: {data.status}</div>}
          </div>
        )
      )}
    </>
  );
};

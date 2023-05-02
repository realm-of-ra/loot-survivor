import React, { useState } from "react";
import { useQuery } from "@apollo/client";
import { getAdventurerByGold } from "../hooks/graphql/queries";
import { Button } from "./Button";
import Coin from "../../../public/coin.svg";

const Leaderboard: React.FC = () => {
  const [currentPage, setCurrentPage] = useState<number>(1);
  const itemsPerPage = 10;

  const { data, loading, error } = useQuery(getAdventurerByGold);

  if (loading) return <p>Loading...</p>;
  if (error) return <p>Error: {error.message}</p>;

  const adventurers = data?.adventurers;
  const totalPages = Math.ceil(adventurers.length / itemsPerPage);

  const handleClick = (newPage: number): void => {
    if (newPage >= 1 && newPage <= totalPages) {
      setCurrentPage(newPage);
    }
  };

  const displayAdventurers = adventurers.slice(
    (currentPage - 1) * itemsPerPage,
    currentPage * itemsPerPage
  );

  let previousGold = -1;
  let currentRank = 0;
  let rankOffset = 0;

  const rankGold = (adventurer: any, index: number) => {
    if (adventurer.gold !== previousGold) {
      currentRank = index + 1 + (currentPage - 1) * itemsPerPage;
      rankOffset = 0;
    } else {
      rankOffset++;
    }
    previousGold = adventurer.gold;
    return currentRank;
  };

  return (
    <div className="flex flex-col items-center w-1/2 m-auto">
      <table className="w-full mt-4 text-4xl border border-terminal-green">
        <thead className="sticky top-0 border border-terminal-green">
          <tr>
            <th>Rank</th>
            <th>Adventurer</th>
            <th>Gold</th>
          </tr>
        </thead>
        <tbody>
          {displayAdventurers.map((adventurer: any, index: number) => {
            return (
              <tr
                key={adventurer.id}
                className="border-b border-terminal-green hover:bg-terminal-green hover:text-terminal-black text-center"
              >
                <td>{rankGold(adventurer, index)}</td>
                <td>{`${adventurer.name} - ${adventurer.id}`}</td>
                <td>
                  <span className="flex text-terminal-yellow justify-center">
                    <Coin className="self-center w-6 h-6 fill-current" />
                    {adventurer.gold}
                  </span>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
      <div className="flex justify-center mt-8">
        <Button
          variant={"outline"}
          onClick={() => handleClick(currentPage - 1)}
        >
          back
        </Button>
        {Array.from({ length: totalPages }, (_, i) => i + 1).map(
          (pageNum: number) => (
            <Button
              variant={"outline"}
              key={pageNum}
              onClick={() => handleClick(pageNum)}
              className={currentPage === pageNum ? "animate-pulse" : ""}
            >
              {pageNum}
            </Button>
          )
        )}
        <Button
          variant={"outline"}
          onClick={() => handleClick(currentPage + 1)}
        >
          next
        </Button>
      </div>
    </div>
  );
};

export default Leaderboard;
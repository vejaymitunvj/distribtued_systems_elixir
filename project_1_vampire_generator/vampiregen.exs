###############################################################################
##
## Description: The application module which accepts the commandline arguments
##              and starts the supervisor
##
##
##
##
###############################################################################
defmodule Vampiregen do
  use Application
  use GenServer, restart: :temporary

  @impl true
  def start(_type, _args) do
    args = System.argv()
    args1 = Enum.at(args, 0) |> String.trim_trailing() |> String.to_integer()
    args2 = Enum.at(args, 1) |> String.trim_trailing() |> String.to_integer()
    argv = [args1, args2]
    ret = start_link(argv)
  end

  def start_link(argv) do
    GenServer.start_link(__MODULE__, argv, name: __MODULE__)
  end

  @impl true
  def init(argv) do
    argsv = {argv, self()}
    VampiregenSupervisor.start_link()
    VampiregenSupervisor.start_child(argsv)
    result = []
    status = :notdone
    IO.puts("WAIT FOR THE RESULTS TO BE COMPUTED:")
    {:ok, {[argv] ,[] ,[]}}
  end

  def print(result) do
    len = length(result)

    for num <- 0..(len - 1) do
      str = Enum.at(result, num)

      if str != [] and str != nil do
        IO.write("\n")
        Enum.each(str, fn x -> IO.write(" #{Integer.to_string(x)} ") end)
      end
    end
  end

  #   This executes periodicall WE ARE NOT USING IT HERE NOWy
    @impl true
   def handle_info(:ready, state) do
     {[argv], batch, result} = state
     status = :notdone
     status = check_status(batch, argv)
     state = case status do
       :done -> 
         result = Enum.sort(result)
         print(result)
         state
       _ ->
          schedule_print()
          state
     end
     {:noreply, state}
   end

    defp schedule_print() do
      Process.send_after(self(), :ready, 1 * 1000) # In 1 seconds
    end

  # catch-all clause for the handle_info for handling  message from our workerss
    @impl true
    def handle_info(msg, state) do
      {:ok, sender_pid, message} = msg
      {argv, batch ,orig_value} = state
      {batch, value} = batch_check(batch, message)
      new_value = orig_value ++ value
      state = {argv, batch, new_value}
     {[argv], batch, result} = state
     status = :notdone
     status = check_status(batch, argv)
     state = case status do
       :done ->
         result = Enum.sort(result)
         print(result)
         IO.puts("") #Empty line
         System.halt(0)
       _ ->
          state
     end
      # terminate(:normal, state)
          {:noreply, state}
    end


  def batch_check(batch, msg) do
    {l1, l2, msg} = msg
    batch = batch ++ [[l1, l2]]
    batch = Enum.uniq(batch)
    batch = Enum.sort(batch)
    {batch, msg}
  end

  def check_status(batch, original_range) do
    [min, max] = original_range
    #    chunk_size =
    batch = List.flatten(batch) 
    batch_len = (length(batch) / 2) |> round
    chunk_size = ((max - min) / batch_len) |> round

    sample_space =
      for num <- 1..batch_len do
        l1 = min + (num - 1) * chunk_size

        l2 =
          if num == batch_len do
            l2 = max
          else
            l2 = min + num * chunk_size - 1
          end

        [l1, l2]
      end
    sample_space = List.flatten(sample_space)
    status =
      if sample_space -- batch == [] do
        :done
      else
        :notdone
      end

    status
  end
end

###############################################################################
##
## Description: The dynamic supervisor module
##              
## NOTE: The children are started individually by the above Vampiregen module
##
##
##
###############################################################################
defmodule VampiregenSupervisor do
  use DynamicSupervisor

  def start_link() do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def start_child(argsv) do
    # If MyWorker is not using the new child specs, we need to pass a map:
    # spec = %{id: MyWorker, start: {MyWorker, :start_link, [foo, bar, baz]}}
    # spec = {MyWorker, foo: foo, bar: bar, baz: baz}
    {[args1, args2], application_pid} = argsv
    count = 5
    range_vec = split_range(args1, args2, count)
    argsv1 = {Enum.at(range_vec, 0), application_pid, :serv1}
    argsv2 = {Enum.at(range_vec, 1), application_pid, :serv2}
    argsv3 = {Enum.at(range_vec, 2), application_pid, :serv3}
    argsv4 = {Enum.at(range_vec, 3), application_pid, :serv4}
    argsv5 = {Enum.at(range_vec, 4), application_pid, :serv5}
    spec1 = {Vampiregenmain, [argsv1]}
    spec2 = {Vampiregenmain, [argsv2]}
    spec3 = {Vampiregenmain, [argsv3]}
    spec4 = {Vampiregenmain, [argsv4]}
    spec5 = {Vampiregenmain, [argsv5]}
    DynamicSupervisor.start_child(__MODULE__, spec1)
    DynamicSupervisor.start_child(__MODULE__, spec2)
    DynamicSupervisor.start_child(__MODULE__, spec3)
    DynamicSupervisor.start_child(__MODULE__, spec4)
    DynamicSupervisor.start_child(__MODULE__, spec5)
  end

  def split_range(first, last, num_split) do
    chunk = ((last - first) / num_split) |> round

    for num <- 1..num_split do
      case num == num_split do
        false -> [first + (num - 1) * chunk, first + num * chunk - 1]
        _ -> [first + (num - 1) * chunk, last]
      end
    end
  end

  @impl true
  def init(_) do
    #  {[args1, args2], application_pid} = argsv

    #    children = [
    # worker(Vampiregenmain,[], restart: :transient)
    #      worker(Vampiregenmain, [argsv1], restart: :temporary),
    #      worker(Vampiregenmain, [argsv2], restart: :temporary),
    #      worker(Vampiregenmain, [argsv3], restart: :temporary),
    #      worker(Vampiregenmain, [argsv4], restart: :temporary),
    #      worker(Vampiregenmain, [argsv5], restart: :temporary)
    #    ]

    DynamicSupervisor.init(strategy: :one_for_one)
  end
end

###############################################################################
##
## Description: The modulee which becomes the worker children and divide the
##              subwork into multiple subtasks
##
##
##
##
###############################################################################

defmodule Vampiregenmain do
  use GenServer, restart: :temporary
  require Integer
  require List

  @moduledoc """
  Documentation for Vampiregen.
  """

  # def start_link(argsv) do
  # [arg1, arg2] = List.flatten(argsv)
  # process_spawner(arg1, arg2)
  # end

  def start_link([argsv]) do
    #   {[vec1, vec2], application_pid, name} = argsv
    #  argsv = {[vec1, vec2], application_pid} 
    {[r1, r2], app_pid, name} = argsv
    argsv = {[r1, r2], app_pid}
    GenServer.start_link(__MODULE__, argsv, name: name)
  end

  def range_Input(argsv) do
    GenServer.cast(self(), {:range_Input, argsv})
  end

  @impl true
  def init(argsv) do
    range_Input(argsv)
    {:ok, argsv}
  end

  def check_state() do
    GenServer.call(__MODULE__, :result)
  end

  @impl true
  def handle_cast({:range_Input, argsv}, state) do
    # in callProcess_spawner() you have to process the arguments split and send to process_spawner() where we have the task worker logic
    {_, state} = callProcess_Spawner(argsv)
    {:noreply, argsv, state}
  end

  @impl true
  def handle_call(:result, _, state) do
    {:reply, state, state}
  end

  def callProcess_Spawner(argsv) do
    # [arg1, arg2] = List.flatten(argsv)
    {[arg1, arg2], client_pid} = argsv
    process_spawner(arg1, arg2, client_pid)
  end

  def process_spawner(args1, args2, client_pid \\ nil) do
    # The threshold value to split into multiple processes
    case args2 - args1 < 5000 do
      true ->
        vampire_filter(args1, args2, client_pid)
        {[], :done}

      false ->
        slice_size = ((args2 - args1) / 4) |> round
        range1_start = args1
        range1_stop = range1_start + slice_size - 1
        range2_start = range1_stop + 1
        range2_stop = range2_start + slice_size - 1
        range3_start = range2_stop + 1
        range3_stop = range3_start + slice_size - 1
        range4_start = range3_stop + 1
        range4_stop = args2
        task1 = Task.async(fn -> vampire_filter(range1_start, range1_stop, client_pid) end)
        task2 = Task.async(fn -> vampire_filter(range2_start, range2_stop, client_pid) end)
        task3 = Task.async(fn -> vampire_filter(range3_start, range3_stop, client_pid) end)
        task4 = Task.async(fn -> vampire_filter(range4_start, range4_stop, client_pid) end)
        Task.await(task1, :infinity)
        Task.await(task2, :infinity)
        Task.await(task3, :infinity)
        Task.await(task4, :infinity)
        {[], :done}
    end
  end

###############################################################################
##
## Description: The function which filters a range of  numbers  
##              looking for vampires 
##
##
##
##
###############################################################################
  @doc """
  Vampire_filter .

  ## Examples

  """

  def vampire_filter(args1, args2, client_pid \\ nil) do
    # Check if number with even digits are within this range 
    # Refine this part to check for even digits within the range
    args1_len = args1 |> Integer.digits() |> length
    args2_len = args2 |> Integer.digits() |> length

    result =
      if args1_len |> Integer.is_even() or
           args2_len |> Integer.is_even() or
           (args2_len - args1_len) |> Integer.is_even() do
        res =
          for num <- args1..args2 do
            res = fang_check(num)

            res =
              if is_list(res) do
                res |> Enum.filter(fn x -> x != nil and x != [] end) |> List.flatten()
              end

            res
          end

        res |> Enum.filter(fn x -> x != nil and x != [] end)
      end

    result |> Enum.filter(fn x -> x != nil and x != [] end)
    {result, :done}

    case is_pid(client_pid) do
      true ->
        message = {args1, args2, result}
        send(client_pid,{:ok, self(), message})
        result
        {result, :done}

      _ ->
        result
        {result, :done}
    end
  end

###############################################################################
##
## Description: The function which decides whether a given number is a vampire  
##               
##
##
##
##
###############################################################################
  @doc """
  Fang Checker.

  ## Examples

      iex> Vampiregen.fang_check(1260)
      [true, 1260, 21, 60]

  """
  def fang_check(num) do
    require Integer
    # Convert the numer to a list
    num_list = num |> Integer.to_charlist()
    # Find the number of digits
    num_len = num_list |> length
    # Check if the number of digits are even else it wont be a vampire
    result =
      if rem(num_len, 2) == 0 do
        k = (num_len / 2) |> round
        # Max limit for one fang
        f1_max = :math.sqrt(num) |> round
        # Min limit for one fang
        f1_min = (num / :math.pow(10, k)) |> round
        fangs_exist_prev = false
        result = []

        result =
          Recursion_fang_filter.scan_potential_fang_list(
            f1_min,
            f1_max,
            num,
            num_list,
            fangs_exist_prev,
            result
          )
      end

    res =
      if is_list(result) do
        List.flatten(result)

        res =
          Enum.filter(result, fn x ->
            x != nil and x != [nil] and x != [[nil]] and not is_boolean(x)
          end)
      end
  end
end

defmodule Recursion_fang_filter do
  def scan_potential_fang_list(f1, f1_max, num, num_list, fangs_exist_prev, result)
      when f1 >= f1_max do
    res_list =
      case result do
        # Do nothing
        [] ->
          [nil]

        nil ->
          result

        _ ->
          List.flatten(result)
      end

    res = fang_condition_check(num, f1, num_list, fangs_exist_prev)

    res_list =
      case res do
        # Do nothing 
        [] ->
          [nil]

        nil ->
          result

        _ ->
          res
      end

    res_list = List.flatten(res_list)
    Enum.uniq(res_list)
  end

  def scan_potential_fang_list(f1, f1_max, num, num_list, fangs_exist_prev, result) do
    res = fang_condition_check(num, f1, num_list, fangs_exist_prev)

    res =
      if is_list(res) do
        List.flatten(res)
        Enum.filter(res, fn x -> x != nil and x != [nil] end)
      end

    res_list =
      case res do
        # Do nothing 
        [] ->
          [nil]

        nil ->
          result

        _ ->
          result ++ res
      end

    flag = extract_flag(res, fangs_exist_prev)
    result = scan_potential_fang_list(f1 + 1, f1_max, num, num_list, flag, res_list)
  end

  def extract_flag(res, old_flag) do
    case is_list(res) do
      true ->
        [flag | _] = res
        flag

      false ->
        old_flag
    end
  end

###############################################################################
##
## Description: Checking if the potential fangs are a proper factor, if they are
##              are having trailing zeroes and doing Modul 9 congruency check 
##              based on the Pete Hartley's theortical proof
##              [source: http://www.primerecords.dk/vampires/index.htm]
##
##
###############################################################################
  def fang_condition_check(num, f1, num_list, fangs_exist_prev) do
    res =
      if rem(num, f1) == 0 do
        f2 = (num / f1) |> round

        if f1 == 205 do
        end

        res =
          if f1 * f2 == num and
               not check_trailing_zero(f1, f2) and
               rem(num, 9) == rem(f1 + f2, 9) do  
            f1_list = f1 |> Integer.to_charlist()
            f2_list = f2 |> Integer.to_charlist()

            if (f1_list ++ f2_list) |> Enum.sort() == num_list |> Enum.sort() do
              #              print_append(fangs_exist_prev, num, f1, f2)
              fangs_exist_prev = true
              [fangs_exist_prev, [num, f1, f2]]
            end
          end
      end
  end

  def check_trailing_zero(f1, f2) do
    if rem(f1, 10) == 0 and rem(f2, 10) == 0 do
      true
    else
      false
    end
  end

  def print_append(fangs_exist, num, f1, f2) do
    if not fangs_exist do
      IO.write("\n#{num} #{f1} #{f2} ")
    else
      IO.write("#{f1} #{f2} ")
    end
  end
end
